using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Transaction
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = null!;
        public required decimal Amount { get; set; }
        public required string Type { get; set; } // Deposit, Withdrawl, Lock, Release, Transfer
        public required string Status { get; set; } // Pending, Completed, Failed
        public required string ExternalPaymentId { get; set; } // PayU
        public required DateTime CreatedAt { get; set; }
    }
}