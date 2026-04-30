using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;

namespace Share_Care.Services
{
    public interface IPaymentService
    {
        Task<string> CreatePayUOrderAsync();
        Task<string> GetAccessTokenAsync();
        Task<PayUOrderRequest> SendOrderRequest();
        PayUOrderRequest BuildOrderRequest();
        Task HandleWebhookNotification();
        bool ValidateWebhookSignature();
        Task<decimal> ProcessSuccessfulPayment();
        Task ProcessFailedPayment();
    }
}