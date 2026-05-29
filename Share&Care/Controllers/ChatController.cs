using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.Services;
using Share_Care.Models.Requests;
using Share_Care.models;
using System.Security.Claims;
using System.Text.Json;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("chat")]
    public class ChatController(IChatService chatService, IMongoDatabase db) : ControllerBase
    {
        private readonly IChatService _chatService = chatService;
        private readonly IMongoCollection<Offer> _offers = db.GetCollection<Offer>("offers");
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly IMongoCollection<Chat> _chats = db.GetCollection<Chat>("chats");

        [Authorize]
        [HttpGet("{chatId}/messages")]
        public async Task<IActionResult> GetHistory(string chatId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var messages = await _chatService.GetMessagesAsync(chatId, userId);

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

            var chat = await _chatService.CreateChatAsync(request.ListingId, buyerId, request.SellerId);

            if (chat == null)
                return NotFound("Sprzedający lub oferta nie istnieje.");

            return CreatedAtAction(nameof(GetHistory), new { chatId = chat.Id }, chat);
        }

        /// <summary>
        /// Zwraca listę czatów zalogowanego użytkownika wraz z podstawowymi
        /// informacjami o ogłoszeniu i drugim uczestniku rozmowy.
        /// </summary>
        [Authorize]
        [HttpGet("my")]
        public async Task<IActionResult> GetMyChats()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var chats = await _chatService.GetUserChatsAsync(userId);

            if (chats.Count == 0)
            {
                return Ok(Array.Empty<ChatSummary>());
            }

            var listingIds = chats.Select(c => c.ListingId).Distinct().ToList();
            var offersCursor = await _offers.FindAsync(o => listingIds.Contains(o.OfferId));
            var offers = await offersCursor.ToListAsync();
            var offersById = offers.ToDictionary(o => o.OfferId, o => o);

            var otherUserIds = chats
                .Select(c => c.BuyerId == userId ? c.SellerId : c.BuyerId)
                .Distinct()
                .ToList();

            var usersCursor = await _users.FindAsync(u => otherUserIds.Contains(u.UserId!));
            var users = await usersCursor.ToListAsync();
            var usersById = users.Where(u => u.UserId != null)
                .ToDictionary(u => u.UserId!, u => u);

            var result = chats
                .Select(c =>
                {
                    offersById.TryGetValue(c.ListingId, out var offer);
                    var otherUserId = c.BuyerId == userId ? c.SellerId : c.BuyerId;
                    usersById.TryGetValue(otherUserId, out var otherUser);

                    var listingStatus = offer?.Status ?? "Deleted";

                    return new ChatSummary
                    {
                        ChatId = c.Id,
                        ListingId = c.ListingId,
                        ListingTitle = offer?.Title ?? string.Empty,
                        ListingStatus = listingStatus,
                        CurrentBorrowerId = offer?.CurrentBorrowerId,
                        OtherUserId = otherUserId,
                        OtherUserName = ((otherUser?.FirstName ?? string.Empty) + " " + (otherUser?.LastName ?? string.Empty)).Trim(),
                        LastMessage = c.LastMessage,
                        LastMessageAt = c.LastMessageAt,
                        ListingFirstImageId = offer?.ImageIds?.FirstOrDefault()
                    };
                })
                .OrderByDescending(c => c.LastMessageAt ?? DateTime.MinValue)
                .ToList();

            return Ok(result);
        }

        /// <summary>
        /// Zwraca zarchiwizowane czaty zalogowanego użytkownika.
        /// </summary>
        [Authorize]
        [HttpGet("history")]
        public async Task<IActionResult> GetChatHistory()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var chats = await _chatService.GetArchivedChatsAsync(userId);

            if (chats.Count == 0)
            {
                return Ok(Array.Empty<ChatSummary>());
            }

            var listingIds = chats.Select(c => c.ListingId).Distinct().ToList();
            var offersCursor = await _offers.FindAsync(o => listingIds.Contains(o.OfferId));
            var offers = await offersCursor.ToListAsync();
            var offersById = offers.ToDictionary(o => o.OfferId, o => o);

            var otherUserIds = chats
                .Select(c => c.BuyerId == userId ? c.SellerId : c.BuyerId)
                .Distinct()
                .ToList();

            var usersCursor = await _users.FindAsync(u => otherUserIds.Contains(u.UserId!));
            var users = await usersCursor.ToListAsync();
            var usersById = users.Where(u => u.UserId != null)
                .ToDictionary(u => u.UserId!, u => u);

            var result = chats
                .Select(c =>
                {
                    offersById.TryGetValue(c.ListingId, out var offer);
                    var otherUserId = c.BuyerId == userId ? c.SellerId : c.BuyerId;
                    usersById.TryGetValue(otherUserId, out var otherUser);

                    var listingStatus = offer?.Status ?? "Deleted";

                    return new ChatSummary
                    {
                        ChatId = c.Id,
                        ListingId = c.ListingId,
                        ListingTitle = offer?.Title ?? string.Empty,
                        ListingStatus = listingStatus,
                        CurrentBorrowerId = offer?.CurrentBorrowerId,
                        OtherUserId = otherUserId,
                        OtherUserName = ((otherUser?.FirstName ?? string.Empty) + " " + (otherUser?.LastName ?? string.Empty)).Trim(),
                        LastMessage = c.LastMessage,
                        LastMessageAt = c.LastMessageAt,
                        ListingFirstImageId = offer?.ImageIds?.FirstOrDefault()
                    };
                })
                .OrderByDescending(c => c.LastMessageAt ?? DateTime.MinValue)
                .ToList();

            return Ok(result);
        }

        /// <summary>
        /// Wysyła wiadomość w kontekście konkretnego czatu.
        /// </summary>
        [Authorize]
        [HttpPost("{chatId}/messages")]
        public async Task<IActionResult> SendMessage(string chatId, [FromBody] SendMessageRequest request)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var senderId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(senderId))
                return Unauthorized();

            var chat = await _chats.Find(c => c.Id == chatId).FirstOrDefaultAsync();
            if (chat is null)
                return NotFound();

            var offer = await _offers.Find(o => o.OfferId == chat.ListingId).FirstOrDefaultAsync();
            if (offer != null && string.Equals(offer.Status, "InProgress", StringComparison.OrdinalIgnoreCase))
            {
                if (!string.Equals(offer.CurrentBorrowerId, senderId, StringComparison.Ordinal))
                {
                    return Forbid();
                }
            }

            var message = await _chatService.SaveMessageAsync(
                chatId,
                senderId,
                request.Content!,
                request.Kind,
                request.DataJson);

            if (message is null)
            {
                // użytkownik nie należy do czatu lub czat nie istnieje
                return Forbid();
            }

            return Ok(message);
        }

        [Authorize]
        [HttpPost("{chatId}/offers")]
        public async Task<IActionResult> SendOfferInChat(string chatId, [FromBody] SendChatOfferRequest request)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var senderId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(senderId))
                return Unauthorized();

            var chat = await _chats.Find(c => c.Id == chatId).FirstOrDefaultAsync();
            if (chat is null)
                return NotFound();

            var report = await _offers.Find(o => o.OfferId == chat.ListingId).FirstOrDefaultAsync();
            if (report is null)
                return NotFound("Zgloszenie nie istnieje.");

            if (!IsReportListing(report))
                return BadRequest("Ten chat nie dotyczy zgloszenia.");

            var offerId = request.OfferId?.Trim();
            if (string.IsNullOrWhiteSpace(offerId))
                return BadRequest("Brak offerId");

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer is null)
                return NotFound("Oferta nie istnieje.");

            if (!string.Equals(offer.UserId, senderId, StringComparison.Ordinal))
                return Forbid();

            var firstImageId = offer.ImageIds is { Count: > 0 }
                ? offer.ImageIds[0]
                : null;

            var payload = JsonSerializer.Serialize(new
            {
                offerId = offer.OfferId,
                title = offer.Title,
                deposit = offer.Deposit,
                offerKind = offer.OfferKind,
                category = offer.Category,
                imageId = firstImageId,
                ownerId = offer.UserId,
                ownerName = offer.ContactName,
                isChatOnly = offer.IsChatOnly,
                status = offer.Status,
                reportId = chat.ListingId
            });

            var message = await _chatService.SaveMessageAsync(
                chatId,
                senderId,
                $"Oferta: {offer.Title}",
                "report_offer",
                payload);

            if (message is null)
                return Forbid();

            return Ok(message);
        }

        private static bool IsReportListing(Offer offer)
        {
            if (string.Equals(offer.OfferKind, "WantToTake", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            var raw = (offer.Category ?? string.Empty).Trim();
            if (raw.Contains('|'))
            {
                var parts = raw.Split('|');
                raw = parts.Length > 0 ? parts[0].Trim() : raw;
            }

            return string.Equals(raw, "Zgloszenie", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// "Usuwa" czat dla bieżącego użytkownika poprzez oznaczenie go jako zarchiwizowany.
        /// Drugi uczestnik nadal widzi konwersację.
        /// </summary>
        [Authorize]
        [HttpDelete("{chatId}")]
        public async Task<IActionResult> ArchiveChat(string chatId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var success = await _chatService.SetArchivedForUserAsync(chatId, userId, true);
            if (!success)
            {
                return NotFound();
            }

            return NoContent();
        }
    }
}