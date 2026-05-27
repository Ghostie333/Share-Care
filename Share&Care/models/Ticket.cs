using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Share_Care.models
{
    public class Ticket
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = null!;

        public string UserId { get; set; } = string.Empty;
        public string? ListingId { get; set; }
        public string? ChatId { get; set; }
        public string? TargetUserId { get; set; }

        public string Reason { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Status { get; set; } = "Open";
        public DateTime CreatedAt { get; set; }
    }
}
