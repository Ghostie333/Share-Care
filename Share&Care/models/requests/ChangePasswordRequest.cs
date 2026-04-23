using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests
{
    public sealed class ChangePasswordRequest
    {
        [Required]
        public string CurrentPassword { get; set; } = string.Empty;

        [Required]
        public string NewPassword { get; set; } = string.Empty;
    }
}
