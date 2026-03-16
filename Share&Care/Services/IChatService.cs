using Share_Care.models;

namespace Share_Care.Services
{
    public interface IChatService
    {
        Task<Chat?> CreateChatAsync(string? listingId, string? buyerId, string? sellerId);
        Task<List<Message>?> GetMessagesAsync(string chatId, string? requestingUserId);
        Task<bool> UserBelongsToChatAsync(string? chatId, string? userId);
        Task<Message?> SaveMessageAsync(string chatId, string? senderId, string content);
    }
}
