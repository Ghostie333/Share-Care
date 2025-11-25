using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Share_Care.models
{
    public class UserData
    {
        [BsonId] // WAŻNE
        [BsonRepresentation(BsonType.ObjectId)]
        public string? UserId { get; set; }  // <- unikalne ID dla Mongo

        public string? Email { get; set; }

        public string? Name { get; set; }

        public string? LastName { get; set; }

        // Id pliku w GridFS (BSON ObjectId przechowywany jako string)
        [BsonRepresentation(BsonType.ObjectId)]
        public string? ProfileImageId { get; set; }
    }
}
