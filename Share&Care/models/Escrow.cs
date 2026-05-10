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
        public required string Status { get; set; } // PendingApproval, Locked, Released, Claimed, Canceled
        public DateTime CreatedAt { get; set; }
        public DateTime? DeadlineAt { get; set; }
        public string? ReturnStatus { get; set; } // TakerReturned, GiverReviewed, Disputed
        public string? Condition { get; set; } // Ideal, LightlyUsed, HeavilyUsed, Destroyed, NotReturned

        [BsonRepresentation(BsonType.ObjectId)]
        public List<string> TakerReturnImageIds { get; set; } = new();

        [BsonRepresentation(BsonType.ObjectId)]
        public List<string> GiverInspectionImageIds { get; set; } = new();

        public DateTime? TakerReturnedAt { get; set; }
        public DateTime? GiverReviewedAt { get; set; }
        public DateTime? InspectionDeadlineAt { get; set; } // Deadline dla inspekacji Givera (2 tygodnie od TakerReturnedAt)

        public decimal? PlatformFee { get; set; }
        public decimal? GiverBonus { get; set; }
        public decimal? GiverAmount { get; set; }
        public decimal? TakerAmount { get; set; }
        
        public DateTime? DisputeCreatedAt { get; set; } // Kiedy zgłoszono dispute
        public string? DisputeStatus { get; set; } // Open, InReview, Resolved
        public string? DisputeReason { get; set; }
    }
}