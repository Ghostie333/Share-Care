using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class OfferFiltersRequest
{
    public string? UserId { get; set; }
    public string? Category { get; set; }
    public string? Status { get; set; } = "Active";
    public string? SearchText { get; set; }

    [Range(-90, 90)]
    public double? Lat { get; set; }

    [Range(-180, 180)]
    public double? Lng { get; set; }

    [Range(0.1, 1000)]
    public double? RadiusKm { get; set; }

    public DateTime? CreatedAfter { get; set; }
    public DateTime? CreatedBefore { get; set; }
}