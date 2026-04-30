using Share_Care.Models.Requests;

namespace Share_Care.models.requests
{
    public class PayUWebhookPayload
    {
        public PayUOrder? Order {  get; set; }
    }

    public class PayUOrder
    {
        public string OrderId { get; set; } = String.Empty;
        public string Status { get; set; } = String.Empty;
    }
}
