using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class WallettService : IWalletService
    {
        public WallettService(ILogger<ChatService> logger, IMongoDatabase db)
        {
        }
    }
}