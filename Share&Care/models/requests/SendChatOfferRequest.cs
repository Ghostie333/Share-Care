using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class SendChatOfferRequest
{
    [Required]
    public string? OfferId { get; set; }
}
