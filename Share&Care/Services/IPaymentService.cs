using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;

namespace Share_Care.Services
{
    public interface IPaymentService
    {
        Task<string> CreatePayUOrderAsync(Transaction transaction);
        Task<string> GetAccessTokenAsync();
        Task<PayUOrderRequest> SendOrderRequest();
        PayUOrderRequest BuildOrderRequest(Transaction tx);
        Task HandleWebhookNotification();
        bool ValidateWebhookSignature();
        Task ProcessSuccessfulPayment(Transaction transaction);
        Task ProcessFailedPayment(Transaction transaction);
    }
}