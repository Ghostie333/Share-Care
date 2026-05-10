using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests
{
    public class GiverReviewRequest
    {
        [Required]
        public string? Condition { get; set; }
    }
}
