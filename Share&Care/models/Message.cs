using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver.GeoJsonObjectModel;

namespace Share_Care.models
{
    public class Message
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; }

        public string ChatId { get; set; }
        public string SenderId { get; set; }
        public string Content { get; set; }
        public string Kind { get; set; } = "text";
        public string? DataJson { get; set; }
        public DateTime SentAt { get; set; }
        public bool IsRead { get; set; }           // warto dodać – znacznik przeczytania
    }
}
