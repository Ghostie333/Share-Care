using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.models.requests;
using Share_Care.Models.Requests;
using System.Linq;

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

            return new PayUOrderRequest
            {
                NotifyUrl = "https://your-api.com/payments/webhook", // To musi byc publiczne inaczej nie zadziala
                CustomerIp = "127.0.0.1",
                MerchantPosId = "bnGiZevr",
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
            var json = await response.Content.ReadFromJsonAsync<PayUOrderResponse>();

            string orderId = json.OrderId;

            // 4. Zapisz ExtrenalId
            await _transactionService.SetExternalIdAsync(transaction.Id, orderId);

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

            var json = await response.Content.ReadFromJsonAsync<dynamic>();

            return json.access_token;
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

            _logger.LogInformation($"Payment success: {transaction.Id}");
        }

        public Task<PayUOrderRequest> SendOrderRequest()
        {
            throw new NotImplementedException();
        }

        public bool ValidateWebhookSignature()
        {
            return true;
        }
    }
}