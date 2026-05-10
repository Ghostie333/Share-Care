namespace Share_Care.models.requests
{
    public class InspectItemRequest
    {
        public required string Condition { get; set; } // Ideal, LightlyUsed, HeavilyUsed, Destroyed
        public required List<string> ImageIds { get; set; }
    }
}
