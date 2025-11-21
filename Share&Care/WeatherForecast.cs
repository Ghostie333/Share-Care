using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Share_Care
{
    public class WeatherForecast
    {
        [BsonId] // WA¯NE
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }  // <- unikalne ID dla Mongo

        public DateTime Date { get; set; }

        public int TemperatureC { get; set; }

        public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);

        public string? Summary { get; set; }
    }
}
