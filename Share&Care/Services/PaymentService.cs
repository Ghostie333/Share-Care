using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class PaymentService : IPaymentService
    {
        public PaymentService(ILogger<PaymentService> logger, IMongoDatabase db)
        {
        }
    }
}