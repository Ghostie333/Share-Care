using Share_Care.models;

namespace Share_Care.Services
{
    public interface IChatService
    {
        Task<Chat?> CreateChatAsync(string? listingId, string? buyerId, string? sellerId);
        Task<List<Message>?> GetMessagesAsync(string chatId, string? requestingUserId);
        Task<bool> UserBelongsToChatAsync(string? chatId, string? userId);
        Task<Message?> SaveMessageAsync(string chatId, string? senderId, string content, string? kind, string? dataJson);

        /// <summary>
        /// Zwraca wszystkie czaty, w których bierze udział dany użytkownik
        /// (jako kupujący lub sprzedający).
        /// </summary>
        Task<List<Chat>> GetUserChatsAsync(string userId);

        /// <summary>
        /// Zwraca zarchiwizowane czaty dla danego użytkownika.
        /// </summary>
        Task<List<Chat>> GetArchivedChatsAsync(string userId);

        /// <summary>
        /// Ustawia stan archiwizacji (aktywne/nieaktywne) dla konkretnego użytkownika.
        /// </summary>
        Task<bool> SetArchivedForUserAsync(string chatId, string userId, bool archived);
    }
}
