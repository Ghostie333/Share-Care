using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;
using System.Linq;

namespace Share_Care.Services
{
    public class PaymentService(ILogger<PaymentService> logger, IMongoDatabase db) : IPaymentService
    {
        private readonly ILogger<PaymentService> _logger = logger;

        public PayUOrderRequest BuildOrderRequest()
        {
            throw new NotImplementedException();
        }

        public Task<string> CreatePayUOrderAsync()
        {
            throw new NotImplementedException();
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

        public Task<decimal> ProcessSuccessfulPaymetn()
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