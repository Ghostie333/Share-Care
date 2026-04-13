using Microsoft.AspNetCore.Http;
using System;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class PayUOrderRequest
{
    public string NotifyUrl { get; set; }
    public string ContinueUrl { get; set; }
    public string CustomerIp { get; set; }
    public string MerchantPosId { get; set; }
    public string Description { get; set; }
    public string CurrencyCode { get; set; }
    public string TotalAmount { get; set; }

    public Buyer Buyer { get; set; }
    public List<Product> Products { get; set; }
}
public class Buyer
{
    public string Email { get; set; }
    public string Phone { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
}

public class Product
{
    public string Name { get; set; }
    public string UnitPrice { get; set; }
    public string Quantity { get; set; }
}
