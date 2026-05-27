using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests
{
    public sealed class CreateTicketRequest
    {
        [Required]
        [MaxLength(120)]
        public string? Reason { get; set; }

        [Required]
        [MaxLength(2000)]
        public string? Description { get; set; }

        public string? ListingId { get; set; }
        public string? ChatId { get; set; }
        public string? TargetUserId { get; set; }
    }
}
