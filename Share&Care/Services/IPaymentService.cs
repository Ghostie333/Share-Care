using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public interface IPaymentService
    {
        Task<string> CreatePayUOrderAsync();
        Task<string> GetAccessTokenAsync();
    }
}