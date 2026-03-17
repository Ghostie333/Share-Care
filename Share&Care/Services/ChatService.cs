using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

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

            var sellerCursor = await _db.GetCollection<UserData>("users")
                .FindAsync(Builders<UserData>.Filter.Eq(u => u.UserId, sellerId));
            var sellerUser = await sellerCursor.FirstOrDefaultAsync();

            var offerCursor = await _db.GetCollection<Offer>("offers")
                .FindAsync(Builders<Offer>.Filter.Eq(o => o.OfferId, listingId));
            var listingOffer = await offerCursor.FirstOrDefaultAsync();

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

            var messagesCursor = await _db.GetCollection<Message>("messages")
                .FindAsync(Builders<Message>.Filter.Eq(mess => mess.ChatId, chatId));
            var messages = await messagesCursor.ToListAsync();

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

            var chatCursor = await _db.GetCollection<Chat>("chats")
                .FindAsync(
                    Builders<Chat>.Filter.And(
                        Builders<Chat>.Filter.Eq(c => c.Id, chatId),
                        Builders<Chat>.Filter.Or(
                            Builders<Chat>.Filter.Eq(c => c.BuyerId, userId),
                            Builders<Chat>.Filter.Eq(c => c.SellerId, userId))));
            var chat = await chatCursor.FirstOrDefaultAsync();

            return chat != null;
        }
    }
}