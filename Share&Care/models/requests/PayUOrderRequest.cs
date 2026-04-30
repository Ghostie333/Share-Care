using Microsoft.AspNetCore.Http;
using System;
using System.ComponentModel.DataAnnotations;

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
        public string Name { get; set; }
        public string UnitPrice { get; set; }
        public string Quantity { get; set; }
    }

    public class PayUOrder
    {
        public string OrderId { get; set; } = String.Empty;
        public string Status { get; set; } = String.Empty;
    }

    public class PayUOrderResponse
    {
        public string OrderId { get; set; } = String.Empty;
        public string RedirectUrl { get; set; } = String.Empty;
    }
}