using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class CreateOfferRequest
{
    [Required]
    [MaxLength(50, ErrorMessage = "Tytuł może mieć maksymalnie 50 znaków.")]
    public string? Title { get; set; }

    [Required]
    public string? ContactName { get; set; }

    [Required]
    public string? Category { get; set; }

    [Required]
    public string? OfferKind { get; set; } // Borrow or Give

    public string ContactNumber { get; set; } = string.Empty;

    [MaxLength(300, ErrorMessage = "Opis może mieć maksymalnie 300 znaków.")]
    public string Description { get; set; } = string.Empty;

    [Range(0, double.MaxValue, ErrorMessage = "Kaucja musi być dodatnia.")]
    public decimal? Deposit { get; set; }

    // Tekstowa lokalizacja podawana w formularzu (miasto / adres).
    public string? LocationText { get; set; }

    [Range(-90, 90, ErrorMessage = "Lat musi być w zakresie [-90, 90].")]
    public double? Lat { get; set; }

    [Range(-180, 180, ErrorMessage = "Lng musi być w zakresie [-180, 180].")]
    public double? Lng { get; set; }

    public DateTime? ExpirationDate { get; set; }

    public List<IFormFile>? Images { get; set; }
}