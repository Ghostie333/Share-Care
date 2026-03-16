using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Share_Care.Services;
using Share_Care.Models.Requests;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("chat")]
    public class ChatController(IChatService chatService) : ControllerBase
    {
        [Authorize]
        [HttpGet("{chatId}/messages")]
        public async Task<IActionResult> GetHistory(string chatId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var messages = await chatService.GetMessagesAsync(chatId, userId);

            if (messages == null)
                return Forbid();

            return Ok(messages);
        }

        [Authorize]
        [HttpPost]
        public async Task<IActionResult> CreateChat([FromBody] CreateChatRequest request)
        {
            var buyerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(buyerId))
                return Unauthorized();

            var chat = await chatService.CreateChatAsync(request.ListingId, buyerId, request.SellerId);

            if (chat == null)
                return NotFound("Sprzedający lub oferta nie istnieje.");

            return CreatedAtAction(nameof(GetHistory), new { chatId = chat.Id }, chat);
        }
    }
}