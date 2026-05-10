using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.models.requests;
using Share_Care.Models.Requests;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace Share_Care.Services
{
    public class PaymentService(ILogger<PaymentService> logger, 
        IMongoDatabase db,
        ITransactionService transactionService,
        IWalletService walletService,
        HttpClient httpClient,
        IConfiguration config) : IPaymentService
    {
        private readonly ILogger<PaymentService> _logger = logger;
        private readonly IMongoDatabase _db = db;
        private readonly ITransactionService _transactionService = transactionService;
        private readonly IWalletService _walletService = walletService;
        private readonly HttpClient _httpClient = httpClient;
        private readonly IConfiguration _config = config;

        public PayUOrderRequest BuildOrderRequest(Transaction tx)
        {
            var amount = ((int)(tx.Amount * 100)).ToString();
            var notifyUrl = _config["PayU:NotifyUrl"] ?? string.Empty;
            var continueUrl = _config["PayU:ContinueUrl"] ?? string.Empty;

            return new PayUOrderRequest
            {
                NotifyUrl = notifyUrl,
                ContinueUrl = continueUrl,
                CustomerIp = "127.0.0.1",
                MerchantPosId = _config["PayU:PosId"], // pos_id z PayU Sandbox
                Description = $"Deposit {tx.Id}",
                CurrencyCode = "PLN",
                TotalAmount = amount,
                ExtOrderId = tx.Id,

                Products = new List<Product>
                {
                    new Product
                    {
                        Name = "Wallet top-up",
                        UnitPrice = amount,
                        Quantity = "1"
                    }
                }
            };
        }

        public async Task<string> CreatePayUOrderAsync(Transaction transaction)
        {
            // 1. Pobierz token
            var token = await GetAccessTokenAsync();

            // 2. Budowa zadania
            var request = BuildOrderRequest(transaction);

            // 3. Wyslanie do PayU
            var httpRequest = new HttpRequestMessage(HttpMethod.Post,
                "https://secure.snd.payu.com/api/v2_1/orders");

            httpRequest.Headers.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

            httpRequest.Content = JsonContent.Create(request);

            var response = await _httpClient.SendAsync(httpRequest);

            var body = await response.Content.ReadAsStringAsync();
            _logger.LogInformation("PayU order response {Status}: {Body}", response.StatusCode, body);

            if (response.StatusCode != System.Net.HttpStatusCode.Found &&
                response.StatusCode != System.Net.HttpStatusCode.OK)
            {
                throw new Exception($"PayU order failed [{response.StatusCode}]: {body}");
            }

            var json = System.Text.Json.JsonSerializer.Deserialize<PayUOrderResponse>(body);

            if (json?.OrderId == null)
                throw new Exception($"PayU response missing orderId: {body}");

            await _transactionService.SetExternalIdAsync(transaction.Id, json.OrderId);

            return json.RedirectUrl;
        }

        public async Task<string> GetAccessTokenAsync()
        {
            var content = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string, string>("grant_type", "client_credentials"),
                new KeyValuePair<string, string>("client_id", _config["PayU:ClientId"]),
                new KeyValuePair<string, string>("client_secret", _config["PayU:ClientSecret"])
            });

            var response = await _httpClient.PostAsync(
                "https://secure.snd.payu.com/pl/standard/user/oauth/authorize",
                content);

            var body = await response.Content.ReadAsStringAsync();
            _logger.LogInformation("PayU token response {Status}: {Body}", response.StatusCode, body);

            if (!response.IsSuccessStatusCode)
                throw new Exception($"PayU auth failed: {body}");

            var json = await response.Content.ReadFromJsonAsync<PayUTokenResponse>();
            return json!.AccessToken;
        }

        public Task HandleWebhookNotification()
        {
            throw new NotImplementedException();
        }

        public async Task ProcessFailedPayment(Transaction transaction)
        {
            if (transaction.Status == "Failed")
                return;

            await _transactionService.MarkAsFailedAsync(transaction.Id);

            _logger.LogWarning($"Payment failed: {transaction.Id}");
        }

        public async Task ProcessSuccessfulPayment(Transaction transaction)
        {
            if (transaction.Status == "Completed")
                return;

            await _transactionService.MarkAsCompletedAsync(transaction.Id);

            await _walletService.AddFundsAsync(transaction.UserId, transaction.Amount);

            var creditsPerPlnRaw = _config["Credits:PerPln"];
            var creditsPerPln = int.TryParse(creditsPerPlnRaw, out var parsed) ? parsed : 1;
            var creditsToAdd = (int)Math.Round(transaction.Amount * creditsPerPln, MidpointRounding.AwayFromZero);
            if (creditsToAdd > 0)
            {
                var users = _db.GetCollection<UserData>("users");
                await users.UpdateOneAsync(
                    u => u.UserId == transaction.UserId,
                    Builders<UserData>.Update.Inc(u => u.Credits, creditsToAdd)
                );
            }

            _logger.LogInformation($"Payment success: {transaction.Id}");
        }

        public Task<PayUOrderRequest> SendOrderRequest()
        {
            throw new NotImplementedException();
        }

        // Walidacja poprawnosci webhooka
        public bool ValidateWebhookSignature(string signatureHeader,
            string requestBody, string secondKey)
        {
            var parts = signatureHeader.Split(';')
                .Select(p => p.Split('=', 2))
                .Where(p => p.Length == 2)
                .ToDictionary(p => p[0], p => p[1]);

            var receivedHash = parts["signature"];
            var bytes = MD5.HashData(Encoding.UTF8.GetBytes(requestBody + secondKey));
            var computed = Convert.ToHexString(bytes).ToLowerInvariant();

            return computed == receivedHash;
        }
    }
}