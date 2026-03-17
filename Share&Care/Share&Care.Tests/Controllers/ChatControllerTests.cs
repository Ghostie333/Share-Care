using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Share_Care.Controllers;
using Share_Care.Models.Requests;
using Share_Care.models;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests.Controllers
{
    public class ChatControllerTests
    {
        [Fact]
        public async Task GetHistory_WhenUserIdMissing_ReturnsUnauthorized()
        {
            var svc = new Mock<IChatService>();
            var controller = new ChatController(svc.Object)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };

            var result = await controller.GetHistory("chat1");

            Assert.IsType<UnauthorizedResult>(result);
        }

        [Fact]
        public async Task GetHistory_WhenMessagesNull_ReturnsForbid()
        {
            var svc = new Mock<IChatService>();
            svc.Setup(s => s.GetMessagesAsync("chat1", "u1"))
               .ReturnsAsync((List<Message>?)null);

            var controller = CreateWithUser(svc.Object, "u1");

            var result = await controller.GetHistory("chat1");

            Assert.IsType<ForbidResult>(result);
        }

        [Fact]
        public async Task GetHistory_WhenMessagesReturned_ReturnsOkWithMessages()
        {
            var svc = new Mock<IChatService>();
            var messages = new List<Message>
            {
                new() { ChatId = "chat1", SenderId = "u1", Content = "hi", SentAt = System.DateTime.UtcNow }
            };

            svc.Setup(s => s.GetMessagesAsync("chat1", "u1"))
               .ReturnsAsync(messages);

            var controller = CreateWithUser(svc.Object, "u1");

            var result = await controller.GetHistory("chat1");

            var ok = Assert.IsType<OkObjectResult>(result);
            Assert.Same(messages, ok.Value);
        }

        [Fact]
        public async Task CreateChat_WhenUserIdMissing_ReturnsUnauthorized()
        {
            var svc = new Mock<IChatService>();
            var controller = new ChatController(svc.Object)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };

            var result = await controller.CreateChat(new CreateChatRequest { ListingId = "l1", SellerId = "s1" });

            Assert.IsType<UnauthorizedResult>(result);
        }

        [Fact]
        public async Task CreateChat_WhenServiceReturnsNull_ReturnsNotFound()
        {
            var svc = new Mock<IChatService>();
            svc.Setup(s => s.CreateChatAsync("l1", "buyer", "seller"))
               .ReturnsAsync((Chat?)null);

            var controller = CreateWithUser(svc.Object, "buyer");

            var result = await controller.CreateChat(new CreateChatRequest { ListingId = "l1", SellerId = "seller" });

            Assert.IsType<NotFoundObjectResult>(result);
        }

        [Fact]
        public async Task CreateChat_WhenServiceReturnsChat_ReturnsCreatedAtAction()
        {
            var svc = new Mock<IChatService>();
            var chat = new Chat { Id = "c1", BuyerId = "buyer", SellerId = "seller", ListingId = "l1", CreatedAt = System.DateTime.UtcNow };

            svc.Setup(s => s.CreateChatAsync("l1", "buyer", "seller"))
               .ReturnsAsync(chat);

            var controller = CreateWithUser(svc.Object, "buyer");

            var result = await controller.CreateChat(new CreateChatRequest { ListingId = "l1", SellerId = "seller" });

            var created = Assert.IsType<CreatedAtActionResult>(result);
            Assert.Equal(nameof(ChatController.GetHistory), created.ActionName);
            Assert.Same(chat, created.Value);
        }

        private static ChatController CreateWithUser(IChatService svc, string userId)
        {
            var http = new DefaultHttpContext();
            http.User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(ClaimTypes.NameIdentifier, userId) },
                authenticationType: "Test"));

            return new ChatController(svc)
            {
                ControllerContext = new ControllerContext { HttpContext = http }
            };
        }
    }
}
