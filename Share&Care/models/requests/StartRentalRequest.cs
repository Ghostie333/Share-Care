using System;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests
{
    public class StartRentalRequest
    {
        [Required]
        public string? OfferId { get; set; }

        public DateTime? DeadlineAt { get; set; }
    }
}
