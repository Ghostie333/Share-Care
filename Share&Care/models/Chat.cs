using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Chat
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = null!;
        public required string BuyerId { get; set; }
        public required string SellerId { get; set; }

        public required string ListingId { get; set; }      // warto dodać – czat dotyczy ogłoszenia
        public required DateTime CreatedAt { get; set; }

        // przyspiesza listę chatów bez odpytywania Messages
        public string? LastMessage { get; set; }    // podgląd ostatniej wiadomości
        public DateTime? LastMessageAt { get; set; }
    }
}
