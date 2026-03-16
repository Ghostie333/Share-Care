using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public class ChatService(ILogger<ChatService> logger, IMongoDatabase db) : IChatService
    {
        private readonly ILogger<ChatService> _logger = logger;
        private readonly IMongoDatabase _db = db;

        public async Task<Chat?> CreateChatAsync(string? listingId, string? buyerId, string? sellerId)
        {
            if (string.IsNullOrWhiteSpace(listingId) ||
                string.IsNullOrWhiteSpace(buyerId) ||
                string.IsNullOrWhiteSpace(sellerId))
                return null;

            var sellerUser = await _db.GetCollection<UserData>("users")
                .Find(u => u.UserId == sellerId)
                .FirstOrDefaultAsync();

            var listingOffer = await _db.GetCollection<Offer>("offers")
                .Find(o => o.OfferId == listingId)
                .FirstOrDefaultAsync();

            if (sellerUser == null || listingOffer == null)
            {
                _logger.LogInformation("Nieudana próba utworzenia chatu: seller lub offer nie istnieje");
                return null;
            }

            var chat = new Chat
            {
                BuyerId = buyerId,
                SellerId = sellerId,
                ListingId = listingId,
                CreatedAt = DateTime.UtcNow,
                LastMessage = null,
                LastMessageAt = null
            };

            await _db.GetCollection<Chat>("chats").InsertOneAsync(chat);

            return chat;
        }

        public async Task<List<Message>?> GetMessagesAsync(string? chatId, string? requestingUserId)
        {
            if (string.IsNullOrWhiteSpace(chatId) || string.IsNullOrWhiteSpace(requestingUserId))
                return null;

            var belongs = await UserBelongsToChatAsync(chatId, requestingUserId);
            if (!belongs) return null;

            var messages = await _db.GetCollection<Message>("messages")
                .Find(mess => mess.ChatId == chatId)
                .SortBy(mess => mess.SentAt)
                .ToListAsync();

            return messages;
        }

        public async Task<Message?> SaveMessageAsync(string chatId, string? senderId, string content)
        {
            if (string.IsNullOrWhiteSpace(chatId) ||
                string.IsNullOrWhiteSpace(senderId) ||
                string.IsNullOrWhiteSpace(content))
                return null;

            var belongs = await UserBelongsToChatAsync(chatId, senderId);
            if (!belongs) return null;

            var message = new Message
            {
                ChatId = chatId,
                SenderId = senderId,
                Content = content,
                SentAt = DateTime.UtcNow,
                IsRead = false
            };

            await _db.GetCollection<Message>("messages").InsertOneAsync(message);

            var update = Builders<Chat>.Update
                .Set(c => c.LastMessage, content)
                .Set(c => c.LastMessageAt, message.SentAt);

            await _db.GetCollection<Chat>("chats")
                .UpdateOneAsync(c => c.Id == chatId, update);

            return message;
        }

        public async Task<bool> UserBelongsToChatAsync(string? chatId, string? userId)
        {
            if (string.IsNullOrWhiteSpace(chatId) || string.IsNullOrWhiteSpace(userId))
                return false;

            var chat = await _db.GetCollection<Chat>("chats")
                .Find(c => c.Id == chatId && (c.BuyerId == userId || c.SellerId == userId))
                .FirstOrDefaultAsync();

            return chat != null;
        }
    }
}