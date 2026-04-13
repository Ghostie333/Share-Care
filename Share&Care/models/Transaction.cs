using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Transaction
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; }
        public string UserId { get; set; }
        public decimal Amount { get; set; }
        public string Type { get; set; } // Deposit, Lock, Unlock, Transfer
        public string Status { get; set; } // Pending, Completed, Failed
        public string? ExternalId { get; set; } // PayU orderId or ExtOrderId
        public DateTime CreatedAt {  get; set; }
    }
}