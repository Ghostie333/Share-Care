using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;
using System.Linq;

namespace Share_Care.Services
{
    public class PaymentService(ILogger<PaymentService> logger, 
        IMongoDatabase db,
        ITransactionService transactionService,
        IWalletService walletService,
        HttpClient httpClient) : IPaymentService
    {
        private readonly ILogger<PaymentService> _logger = logger;
        private readonly IMongoDatabase _db = db;
        private readonly ITransactionService _transactionService = transactionService;
        private readonly IWalletService _walletService = walletService;
        private readonly HttpClient _httpClient = httpClient;

        public PayUOrderRequest BuildOrderRequest(Transaction tx)
        {
            throw new NotImplementedException();
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
            var json = await response.Content.ReadFromJsonAsync<dynamic>();

            string orderId = json.orderId;

            // 4. Zapisz ExtrenalId
            await _transactionService.SetExternalIdAsync(transaction.Id, orderId);

            return json.redirectUrl;
        }

        public Task<string> GetAccessTokenAsync()
        {
            throw new NotImplementedException();
        }

        public Task HandleWebhookNotification()
        {
            throw new NotImplementedException();
        }

        public Task ProcessFailedPayment()
        {
            throw new NotImplementedException();
        }

        public Task<decimal> ProcessSuccessfulPayment()
        {
            throw new NotImplementedException();
        }

        public Task<PayUOrderRequest> SendOrderRequest()
        {
            throw new NotImplementedException();
        }

        public bool ValidateWebhookSignature()
        {
            throw new NotImplementedException();
        }
    }
}