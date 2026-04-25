using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class CreateOfferRequest
{
    [Required]
    public string? Title { get; set; }

    [Required]
    public string? ContactName { get; set; }

    [Required]
    public string? Category { get; set; }

    public string ContactNumber { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    [Range(0, double.MaxValue, ErrorMessage = "Kaucja musi być dodatnia.")]
    public decimal? Deposit { get; set; }

    // Tekstowa lokalizacja podawana w formularzu (miasto / adres).
    public string? LocationText { get; set; }

    [Range(-90, 90, ErrorMessage = "Lat musi być w zakresie [-90, 90].")]
    public double? Lat { get; set; }

    [Range(-180, 180, ErrorMessage = "Lng musi być w zakresie [-180, 180].")]
    public double? Lng { get; set; }

    public List<IFormFile>? Images { get; set; }
}