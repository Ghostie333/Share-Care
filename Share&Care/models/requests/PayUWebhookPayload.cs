using Share_Care.Models.Requests;
using System.Text.Json.Serialization;

namespace Share_Care.models.requests
{
    public class PayUWebhookPayload
    {
        [JsonPropertyName("order")]
        public PayUOrder? Order { get; set; }

        [JsonPropertyName("localReceiptDateTime")]
        public string? LocalReceiptDateTime { get; set; }

        [JsonPropertyName("properties")]
        public List<object>? Properties { get; set; }
    }

    public class PayUOrder
    {
        [JsonPropertyName("orderId")]
        public string? OrderId { get; set; }

        [JsonPropertyName("extOrderId")]
        public string? ExtOrderId { get; set; }

        [JsonPropertyName("orderCreateDate")]
        public string? OrderCreateDate { get; set; }

        [JsonPropertyName("notifyUrl")]
        public string? NotifyUrl { get; set; }

        [JsonPropertyName("customerIp")]
        public string? CustomerIp { get; set; }

        [JsonPropertyName("merchantPosId")]
        public string? MerchantPosId { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("currencyCode")]
        public string? CurrencyCode { get; set; }

        [JsonPropertyName("totalAmount")]
        public string? TotalAmount { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }
    }
}
