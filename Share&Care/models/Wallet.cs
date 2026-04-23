using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Wallet
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = null!;
        public required string UserId { get; set; }
        public decimal Balance { get; set; } = decimal.Zero;
        public decimal LockedBalance { get; set; } = decimal.Zero;

        public decimal GetAvailableBalance()
        {
            return Balance;
        }

        public bool HasSufficientFunds(decimal amount)
        {
            return GetAvailableBalance() >= amount;
        }
    }
}