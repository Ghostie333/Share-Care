using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Share_Care.Services;
using System.Security.Claims;

namespace Share_Care.Hubs
{
    [Authorize]
    public class ChatHub(IChatService chatService) : Hub
    {
        public async Task JoinChat(string chatId)
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(chatId))
            {
                Context.Abort();
                return;
            }

            var belongs = await chatService.UserBelongsToChatAsync(chatId, userId);
            if (!belongs)
            {
                Context.Abort();
                return;
            }

            await Groups.AddToGroupAsync(Context.ConnectionId, chatId);
        }

        public async Task LeaveChat(string chatId)
        {
            if (string.IsNullOrWhiteSpace(chatId))
                return;

            await Groups.RemoveFromGroupAsync(Context.ConnectionId, chatId);
        }

        public async Task SendMessage(string chatId, string content)
        {
            var senderId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrWhiteSpace(senderId) ||
                string.IsNullOrWhiteSpace(chatId) ||
                string.IsNullOrWhiteSpace(content))
                return;

            var belongs = await chatService.UserBelongsToChatAsync(chatId, senderId);
            if (!belongs)
                return;

            var message = await chatService.SaveMessageAsync(chatId, senderId, content);
            if (message is null)
                return;

            await Clients.Group(chatId).SendAsync("ReceiveMessage", message);
        }
    }
}