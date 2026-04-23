using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MongoDB.Driver;
using Moq;
using Share_Care.models;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests
{
    public class ChatServiceTests
    {
        [Fact]
        public async Task CreateChatAsync_WhenAnyArgumentIsMissing_ReturnsNull()
        {
            var logger = new Mock<ILogger<ChatService>>();
            var db = new Mock<IMongoDatabase>();
            var service = new ChatService(logger.Object, db.Object);

            Assert.Null(await service.CreateChatAsync(null, "buyer", "seller"));
            Assert.Null(await service.CreateChatAsync("listing", null, "seller"));
            Assert.Null(await service.CreateChatAsync("listing", "buyer", null));
            Assert.Null(await service.CreateChatAsync(" ", "buyer", "seller"));
        }

        [Fact]
        public async Task CreateChatAsync_WhenSellerOrOfferMissing_ReturnsNull()
        {
            // Arrange
            var usersCollection = MongoCursorStub.UserData(new List<UserData>());
            var offersCollection = MongoCursorStub.Offer(new List<Offer>());
            var chatsCollection = new Mock<IMongoCollection<Chat>>();

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<UserData>("users", null)).Returns(usersCollection.Object);
            db.Setup(d => d.GetCollection<Offer>("offers", null)).Returns(offersCollection.Object);
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.CreateChatAsync("listing1", "buyer1", "seller1");

            // Assert
            Assert.Null(result);
            chatsCollection.Verify(c => c.InsertOneAsync(It.IsAny<Chat>(), null, It.IsAny<CancellationToken>()), Times.Never);
        }

        [Fact]
        public async Task CreateChatAsync_WhenSellerAndOfferExist_InsertsChatAndReturnsIt()
        {
            // Arrange
            var seller = new UserData { UserId = "seller1", Email = "s@example.com" };
            var offer = new Offer { OfferId = "listing1", UserId = "seller1", Title = "t", ContactName = "c", ContactNumber = "n", Category = "cat", CreatedAt = DateTime.UtcNow };

            var usersCollection = MongoCursorStub.UserData(new List<UserData> { seller });
            var offersCollection = MongoCursorStub.Offer(new List<Offer> { offer });
            var chatsCollection = new Mock<IMongoCollection<Chat>>();

            Chat? inserted = null;
            chatsCollection
                .Setup(c => c.InsertOneAsync(It.IsAny<Chat>(), null, It.IsAny<CancellationToken>()))
                .Callback<Chat, InsertOneOptions?, CancellationToken>((chat, _, __) => inserted = chat)
                .Returns(Task.CompletedTask);

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<UserData>("users", null)).Returns(usersCollection.Object);
            db.Setup(d => d.GetCollection<Offer>("offers", null)).Returns(offersCollection.Object);
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.CreateChatAsync("listing1", "buyer1", "seller1");

            // Assert
            Assert.NotNull(result);
            Assert.Equal("buyer1", result!.BuyerId);
            Assert.Equal("seller1", result.SellerId);
            Assert.Equal("listing1", result.ListingId);
            Assert.True(result.CreatedAt > DateTime.UtcNow.AddMinutes(-1));

            chatsCollection.Verify(c => c.InsertOneAsync(It.IsAny<Chat>(), null, It.IsAny<CancellationToken>()), Times.Once);
            Assert.NotNull(inserted);
        }

        [Fact]
        public async Task UserBelongsToChatAsync_WhenInputMissing_ReturnsFalse()
        {
            var logger = new Mock<ILogger<ChatService>>();
            var db = new Mock<IMongoDatabase>();
            var service = new ChatService(logger.Object, db.Object);

            Assert.False(await service.UserBelongsToChatAsync(null, "u"));
            Assert.False(await service.UserBelongsToChatAsync("c", null));
            Assert.False(await service.UserBelongsToChatAsync(" ", "u"));
        }

        [Fact]
        public async Task GetMessagesAsync_WhenUserDoesNotBelongToChat_ReturnsNull()
        {
            // Arrange: chats query returns none
            var chatsCollection = MongoCursorStub.Chat(new List<Chat>());
            var messagesCollection = new Mock<IMongoCollection<Message>>();

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsCollection.Object);
            db.Setup(d => d.GetCollection<Message>("messages", null)).Returns(messagesCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.GetMessagesAsync("chat1", "user1");

            // Assert
            Assert.Null(result);
            messagesCollection.VerifyNoOtherCalls();
        }

        [Fact]
        public async Task GetMessagesAsync_WhenUserBelongsToChat_ReturnsMessages()
        {
            // Arrange: chat belongs
            var chatsCollection = MongoCursorStub.Chat(new List<Chat>
            {
                new Chat { Id = "chat1", BuyerId = "user1", SellerId = "seller1", ListingId = "l1", CreatedAt = DateTime.UtcNow }
            });

            var messageList = new List<Message>
            {
                new() { ChatId = "chat1", SenderId = "user1", Content = "a", SentAt = DateTime.UtcNow.AddMinutes(-1) },
                new() { ChatId = "chat1", SenderId = "seller1", Content = "b", SentAt = DateTime.UtcNow }
            };

            var messagesCollection = MongoCursorStub.Message(messageList);

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsCollection.Object);
            db.Setup(d => d.GetCollection<Message>("messages", null)).Returns(messagesCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.GetMessagesAsync("chat1", "user1");

            // Assert
            Assert.NotNull(result);
            Assert.Equal(2, result!.Count);
            Assert.Equal("a", result[0].Content);
            Assert.Equal("b", result[1].Content);
        }

        [Fact]
        public async Task SaveMessageAsync_WhenUserDoesNotBelongToChat_ReturnsNull()
        {
            // Arrange: chats query returns none
            var chatsCollection = MongoCursorStub.Chat(new List<Chat>());
            var messagesCollection = new Mock<IMongoCollection<Message>>();

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsCollection.Object);
            db.Setup(d => d.GetCollection<Message>("messages", null)).Returns(messagesCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.SaveMessageAsync("chat1", "user1", "hi");

            // Assert
            Assert.Null(result);
            messagesCollection.Verify(c => c.InsertOneAsync(It.IsAny<Message>(), null, It.IsAny<CancellationToken>()), Times.Never);
        }

        [Fact]
        public async Task SaveMessageAsync_WhenUserBelongs_InsertsMessageAndUpdatesChat_AndReturnsMessage()
        {
            // Arrange
            var chatsCollection = MongoCursorStub.Chat(new List<Chat>
            {
                new Chat { Id = "chat1", BuyerId = "user1", SellerId = "seller1", ListingId = "l1", CreatedAt = DateTime.UtcNow }
            });

            var messagesCollection = new Mock<IMongoCollection<Message>>();
            var usersCollection = MongoCursorStub.UserData(new List<UserData>());
            var offersCollection = MongoCursorStub.Offer(new List<Offer>());

            Message? insertedMessage = null;
            messagesCollection
                .Setup(c => c.InsertOneAsync(It.IsAny<Message>(), null, It.IsAny<CancellationToken>()))
                .Callback<Message, InsertOneOptions?, CancellationToken>((m, _, __) => insertedMessage = m)
                .Returns(Task.CompletedTask);

            var chatsUpdate = new Mock<IMongoCollection<Chat>>();
            chatsUpdate
                .Setup(c => c.FindAsync(
                    It.IsAny<FilterDefinition<Chat>>(),
                    It.IsAny<FindOptions<Chat, Chat>>(),
                    It.IsAny<CancellationToken>()))
                .ReturnsAsync(chatsCollection.Object.FindAsync(
                    Builders<Chat>.Filter.Empty,
                    new FindOptions<Chat, Chat>(),
                    CancellationToken.None).Result);

            chatsUpdate
                .Setup(c => c.UpdateOneAsync(
                    It.IsAny<FilterDefinition<Chat>>(),
                    It.IsAny<UpdateDefinition<Chat>>(),
                    It.IsAny<UpdateOptions>(),
                    It.IsAny<CancellationToken>()))
                .ReturnsAsync(new UpdateResult.Acknowledged(1, 1, null));

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<Chat>("chats", null)).Returns(chatsUpdate.Object);
            db.Setup(d => d.GetCollection<Message>("messages", null)).Returns(messagesCollection.Object);
            db.Setup(d => d.GetCollection<UserData>("users", null)).Returns(usersCollection.Object);
            db.Setup(d => d.GetCollection<Offer>("offers", null)).Returns(offersCollection.Object);

            var logger = new Mock<ILogger<ChatService>>();
            var service = new ChatService(logger.Object, db.Object);

            // Act
            var result = await service.SaveMessageAsync("chat1", "user1", "hello");

            // Assert
            Assert.NotNull(result);
            Assert.Equal("chat1", result!.ChatId);
            Assert.Equal("user1", result.SenderId);
            Assert.Equal("hello", result.Content);

            messagesCollection.Verify(c => c.InsertOneAsync(It.IsAny<Message>(), null, It.IsAny<CancellationToken>()), Times.Once);
            chatsUpdate.Verify(c => c.UpdateOneAsync(
                It.IsAny<FilterDefinition<Chat>>(),
                It.IsAny<UpdateDefinition<Chat>>(),
                It.IsAny<UpdateOptions>(),
                It.IsAny<CancellationToken>()), Times.Once);

            Assert.NotNull(insertedMessage);
        }

        private static class MongoCursorStub
        {
            public static Mock<IMongoCollection<UserData>> UserData(List<UserData> docs) => Collection(docs);
            public static Mock<IMongoCollection<Offer>> Offer(List<Offer> docs) => Collection(docs);
            public static Mock<IMongoCollection<Chat>> Chat(List<Chat> docs) => Collection(docs);
            public static Mock<IMongoCollection<Message>> Message(List<Message> docs) => Collection(docs);

            private static Mock<IMongoCollection<T>> Collection<T>(List<T> docs)
            {
                var collection = new Mock<IMongoCollection<T>>();

                var asyncCursor = new Mock<IAsyncCursor<T>>();
                asyncCursor.SetupSequence(c => c.MoveNextAsync(It.IsAny<CancellationToken>()))
                    .ReturnsAsync(true)
                    .ReturnsAsync(false);
                asyncCursor.SetupGet(c => c.Current).Returns(docs);

                collection
                    .Setup(c => c.FindAsync(
                        It.IsAny<FilterDefinition<T>>(),
                        It.IsAny<FindOptions<T, T>>(),
                        It.IsAny<CancellationToken>()))
                    .ReturnsAsync(asyncCursor.Object);

                return collection;
            }
        }
    }
}
