using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class CreateChatRequest
{
    [Required]
    public string? SellerId { get; set; }

    [Required]
    public string? ListingId { get; set; }
}