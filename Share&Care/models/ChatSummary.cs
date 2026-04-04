using System;

namespace Share_Care.models
{
    /// <summary>
    /// Uproszczony model zwracany w liście czatów użytkownika.
    /// Zawiera podstawowe informacje o ogłoszeniu i drugim uczestniku rozmowy.
    /// </summary>
    public sealed class ChatSummary
    {
        public string ChatId { get; set; } = null!;
        public string ListingId { get; set; } = null!;
        public string ListingTitle { get; set; } = string.Empty;
        /// <summary>
        /// Status ogłoszenia powiązanego z czatem: "Active", "Inactive" lub "Deleted".
        /// </summary>
        public string ListingStatus { get; set; } = string.Empty;

        public string OtherUserId { get; set; } = null!;
        public string OtherUserName { get; set; } = string.Empty;

        public string? LastMessage { get; set; }
        public DateTime? LastMessageAt { get; set; }

        /// <summary>
        /// Identyfikator pierwszego zdjęcia ogłoszenia (GridFS ObjectId jako string),
        /// używany na froncie do miniatury.
        /// </summary>
        public string? ListingFirstImageId { get; set; }
    }
}
