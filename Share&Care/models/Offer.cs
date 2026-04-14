using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Offer
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string OfferId { get; set; }
        public string UserId { get; set; }
        public string Title { get; set; }

        public DateTime CreatedAt { get; set; }
        public string ContactName { get; set; }
        public decimal Deposit { get; set; } = 0;

        public string ContactNumber { get; set; }
        public string? Description { get; set; }
        public string Category { get; set; }
        public string Status { get; set; } = "Active";

        // GeoJSON Point (dla zapytań geolokalizacyjnych i indeksu 2dsphere)
        public GeoJsonPoint<GeoJson2DGeographicCoordinates>? Location { get; set; } 

        // Tekstowa lokalizacja (miasto / adres) widoczna w szczegółach ogłoszenia.
        public string? LocationText { get; set; }

        // Wiele obrazów w GridFS (lista ObjectId jako string)
        [BsonRepresentation(BsonType.ObjectId)]
        public List<string> ImageIds { get; set; } = new(); 
    }
}
