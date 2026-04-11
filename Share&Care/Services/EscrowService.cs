using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class EscrowService : IEscrowService
    {
        public EscrowService(ILogger<ChatService> logger, IMongoDatabase db)
        {
        }
    }
}