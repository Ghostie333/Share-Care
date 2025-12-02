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
        public string? Password { get; set; }

        public string? FirstName { get; set; }

        public string? LastName { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Brithday { get; set; }
        public string? City { get; set; }
        public string? PostalCode { get; set; }
        public string? Type { get; set; }
        public int? OffersAmount { get; set; }
        public float? Raiting { get; set; }

        // Id pliku w GridFS (BSON ObjectId przechowywany jako string)
        [BsonRepresentation(BsonType.ObjectId)]
        public string? ProfileImageId { get; set; }
    }
}
