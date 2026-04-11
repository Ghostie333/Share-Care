using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Escrow
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = null!;
        public required string BorrowerId { get; set; }
        public required string LenderId { get; set; }
        public required string OfferId { get; set; }
        public required decimal Amount { get; set; }
        public required string Status { get; set; } // Locked, Released, Claimed
    }
}