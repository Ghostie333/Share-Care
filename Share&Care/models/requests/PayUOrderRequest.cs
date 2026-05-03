using Microsoft.AspNetCore.Http;
using System;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Share_Care.Models.Requests
{
    public class PayUOrderRequest
    {
        public string NotifyUrl { get; set; } = String.Empty;
        public string CustomerIp { get; set; } = String.Empty;
        public string MerchantPosId { get; set; } = String.Empty;
        public string Description { get; set; } = String.Empty;
        public string CurrencyCode { get; set; } = "PLN";
        public string TotalAmount { get; set; } = String.Empty;
        public string ExtOrderId { get; set; } = String.Empty;

        public List<Product> Products { get; set; } = new();
    }

    public class Product
    {
        public string Name { get; set; } = String.Empty;
        public string UnitPrice { get; set; } = String.Empty;
        public string Quantity { get; set; } = String.Empty;
    }

    public class PayUOrderResponse
    {
        [JsonPropertyName("orderId")]
        public string OrderId { get; set; } = null!;

        [JsonPropertyName("redirectUri")]  
        public string RedirectUrl { get; set; } = null!;
    }

    public class PayUTokenResponse
    {
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = null!;
    }
}