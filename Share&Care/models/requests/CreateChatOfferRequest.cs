using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class CreateChatOfferRequest
{
    [Required]
    public string? ReportId { get; set; }

    [Required]
    [MaxLength(50, ErrorMessage = "Tytul moze miec maksymalnie 50 znakow.")]
    public string? Title { get; set; }

    [Required]
    public string? ContactName { get; set; }

    [Required]
    public string? Category { get; set; }

    [Required]
    public string? OfferKind { get; set; } // Borrow or Give

    public string ContactNumber { get; set; } = string.Empty;

    [MaxLength(300, ErrorMessage = "Opis moze miec maksymalnie 300 znakow.")]
    public string Description { get; set; } = string.Empty;

    [Range(0, double.MaxValue, ErrorMessage = "Kaucja musi byc dodatnia.")]
    public decimal? Deposit { get; set; }

    public string? LocationText { get; set; }

    public DateTime? ExpirationDate { get; set; }

    public List<IFormFile>? Images { get; set; }
}
