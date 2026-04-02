using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class SendMessageRequest
{
    [Required]
    public string? Content { get; set; }
}
