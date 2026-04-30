using Share_Care.Models.Requests;

namespace Share_Care.models.requests
{
    public class Product
    {
        public string Name { get; set; } = String.Empty;
        public string UnitPrice {  get; set; } = String.Empty;
        public string Quantity {  get; set; } = String.Empty;
    }

    public class PayUWebhookPayload
    {
        public PayUOrder? Order {  get; set; }
    }
}
