using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests
{
    public class RedeemRewardRequest
    {
        [Required]
        public string? RewardId { get; set; }
    }
}
