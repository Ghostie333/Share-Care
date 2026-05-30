using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using Share_Care.models;
using Share_Care.Models.Requests;
using Share_Care.Services;
using System.Security.Claims;
using System.Globalization;
using System.Text.Json;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("rental")]
    public class RentalController(
        IEscrowService escrowService,
        IChatService chatService,
        IRewardsService rewardsService,
        IMongoDatabase db,
        IConfiguration config,
        GridFSBucket? gridFs = null) : ControllerBase
    {
        private readonly IEscrowService _escrowService = escrowService;
        private readonly IChatService _chatService = chatService;
        private readonly IRewardsService _rewardsService = rewardsService;
        private readonly IMongoCollection<Offer> _offers = db.GetCollection<Offer>("offers");
        private readonly IMongoCollection<Escrow> _escrows = db.GetCollection<Escrow>("escrows");
        private readonly IMongoCollection<Chat> _chats = db.GetCollection<Chat>("chats");
        private readonly GridFSBucket? _gridFS = gridFs;
        private readonly IConfiguration _config = config;

        [Authorize]
        [HttpPost("start")]
        public async Task<IActionResult> StartRental([FromBody] StartRentalRequest request)
        {
            var borrowerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(borrowerId))
                return Unauthorized();

            if (string.IsNullOrWhiteSpace(request.OfferId))
                return BadRequest("Missing offerId");

            var offer = await _offers.Find(o => o.OfferId == request.OfferId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound("Offer not found");

            if (offer.UserId == borrowerId)
                return BadRequest("Cannot rent own offer");

            if (!string.Equals(offer.Status, "Active", StringComparison.OrdinalIgnoreCase))
                return BadRequest("Offer not available");

            Escrow? escrow = null;
            if (string.Equals(offer.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase))
            {
                if (offer.Deposit == null || offer.Deposit <= 0)
                    return BadRequest("Deposit required for borrowing");

                escrow = await _escrowService.CreateEscrowAsync(
                    borrowerId,
                    offer.UserId,
                    offer.OfferId,
                    offer.Deposit.Value,
                    request.DeadlineAt);

                if (escrow == null)
                    return BadRequest("Insufficient funds to lock deposit");

                var update = Builders<Offer>.Update
                    .Set(o => o.Status, "PendingApproval")
                    .Set(o => o.CurrentBorrowerId, borrowerId)
                    .Set(o => o.RentalDeadlineAt, request.DeadlineAt)
                    .Unset(o => o.RentalStartedAt)
                    .Unset(o => o.CompletedAt);

                await _offers.UpdateOneAsync(o => o.OfferId == offer.OfferId, update);

                offer.Status = "PendingApproval";
                offer.CurrentBorrowerId = borrowerId;
                offer.RentalDeadlineAt = request.DeadlineAt;
            }
            else if (string.Equals(offer.OfferKind, "Give", StringComparison.OrdinalIgnoreCase))
            {
                var update = Builders<Offer>.Update
                    .Set(o => o.Status, "PendingApproval")
                    .Set(o => o.CurrentBorrowerId, borrowerId);

                await _offers.UpdateOneAsync(o => o.OfferId == offer.OfferId, update);

                var result = await _offers.UpdateOneAsync(
                                        o => o.OfferId == offer.OfferId,
                                        update);

                Console.WriteLine($"MATCHED: {result.MatchedCount}");
                Console.WriteLine($"MODIFIED: {result.ModifiedCount}");

                // aktualizacja lokalnego obiektu
                offer.Status = "PendingApproval";
                offer.CurrentBorrowerId = borrowerId;
            }

            Chat? chat = null;
            if (!string.IsNullOrWhiteSpace(request.ChatId))
            {
                chat = await _chats.Find(c => c.Id == request.ChatId).FirstOrDefaultAsync();
                if (chat != null)
                {
                    var belongs = chat.BuyerId == borrowerId || chat.SellerId == borrowerId;
                    var otherId = chat.BuyerId == borrowerId ? chat.SellerId : chat.BuyerId;
                    if (!belongs || !string.Equals(otherId, offer.UserId, StringComparison.Ordinal))
                    {
                        chat = null;
                    }
                }
            }

            chat ??= await _chatService.CreateChatAsync(offer.OfferId, borrowerId, offer.UserId);
            if (chat != null)
            {
                var payload = JsonSerializer.Serialize(new
                {
                    offerId = offer.OfferId,
                    escrowId = escrow?.Id,
                    deadlineAt = request?.DeadlineAt,
                    amount = offer?.Deposit,
                    offerKind = offer.OfferKind,
                    takerId = borrowerId,
                    giverId = offer.UserId
                });

                if (string.Equals(offer.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase))
                {
                    await _chatService.SaveMessageAsync(
                        chat.Id,
                        borrowerId,
                        "Nowa prośba o wypożyczenie",
                        "rental_request",
                        payload);
                }
                else if (string.Equals(offer.OfferKind, "Give", StringComparison.OrdinalIgnoreCase))
                {
                    await _chatService.SaveMessageAsync(
                        chat.Id,
                        borrowerId,
                        "Nowa prośba o oddanie",
                        "give_request",
                        payload);
                }
            }

            return Ok(new { escrowId = escrow?.Id });
        }

        [Authorize]
        [HttpPost("approve/{offerId}")]
        public async Task<IActionResult> ApproveRental(string offerId)
        {
            var giverId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(giverId))
                return Unauthorized();

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound();

            if (!string.Equals(offer.UserId, giverId, StringComparison.Ordinal))
                return Forbid();

            if (string.Equals(offer.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase))
            {
                var approved = await _escrowService.ApproveEscrowAsync(offerId);
                if (!approved)
                    return BadRequest("Escrow not ready for approval");

                var update = Builders<Offer>.Update
                    .Set(o => o.Status, "InProgress")
                    .Set(o => o.RentalStartedAt, DateTime.UtcNow);

                await _offers.UpdateOneAsync(o => o.OfferId == offerId, update);
            }
            else
            {
                await _offers.DeleteOneAsync(o => o.OfferId == offerId);
                await _rewardsService.AwardGiverBonusAsync(offer.UserId, 10);

                await SendRentalUpdateMessage(offer, giverId, "give_approved", "Giver zaakceptował prośbę");

                return Ok(new { 
                    message = "Prośba o oddanie zaakceptowana",
                });
            }

            await SendRentalUpdateMessage(offer, giverId, "rental_approved", "Giver zaakceptował prośbę");

            return Ok();
        }

        [Authorize]
        [HttpPost("decline/{offerId}")]
        public async Task<IActionResult> DeclineRental(string offerId)
        {
            var giverId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(giverId))
                return Unauthorized();

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound();

            if (offer.Status == "InProgress")
                return Forbid();

            if (!string.Equals(offer.UserId, giverId, StringComparison.Ordinal))
                return Forbid();

            if (string.Equals(offer.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase))
            {
                await _escrowService.CancelEscrowAsync(offerId);
            }

            var update = Builders<Offer>.Update
                .Set(o => o.Status, "Active")
                .Set(o => o.CurrentBorrowerId, null)
                .Set(o => o.RentalDeadlineAt, null)
                .Set(o => o.RentalStartedAt, null);

            await _offers.UpdateOneAsync(o => o.OfferId == offerId, update);

            var declineMessage = string.Equals(offer.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase)
                ? "Giver odrzucił prośbę. Kaucja wróciła na konto takera."
                : "Giver odrzucił prośbę.";

            await SendRentalUpdateMessage(offer, giverId, "rental_declined", declineMessage);

            return Ok();
        }

        [Authorize]
        [HttpPost("taker-return/{offerId}")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> TakerReturn([FromForm] List<IFormFile>? images, string offerId)
        {
            var borrowerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(borrowerId))
                return Unauthorized();

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound();

            if (!string.Equals(offer.CurrentBorrowerId, borrowerId, StringComparison.Ordinal))
                return Forbid();

            var imageIds = await UploadImagesAsync(images, borrowerId);
            var updated = await _escrowService.RecordTakerReturnAsync(offerId, imageIds);
            if (!updated)
                return BadRequest("Escrow not ready for return");

            // Ustaw deadline dla inspekcji Givera (14 dni)
            await _escrowService.SetInspectionDeadlineAsync(offerId, 14);

            await _offers.UpdateOneAsync(
                o => o.OfferId == offerId,
                Builders<Offer>.Update.Set(o => o.Status, "ReturnPending"));

            await SendRentalUpdateMessage(offer, borrowerId, "rental_returned", "Taker zgłosił zwrot przedmiotu");

            return Ok();
        }

        [Authorize]
        [HttpPost("giver-review/{offerId}")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> GiverReview([FromForm] GiverReviewRequest request, [FromForm] List<IFormFile>? images, string offerId)
        {
            var giverId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(giverId))
                return Unauthorized();

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound();

            if (!string.Equals(offer.UserId, giverId, StringComparison.Ordinal))
                return Forbid();

            var imageIds = await UploadImagesAsync(images, giverId);
            if (imageIds.Count > 0)
            {
                var updateImages = Builders<Escrow>.Update
                    .Set(e => e.GiverInspectionImageIds, imageIds);
                await _escrows.UpdateOneAsync(e => e.OfferId == offerId, updateImages);
            }

            var ok = await _escrowService.FinalizeEscrowAsync(
                offerId,
                request.Condition ?? "Ideal");

            if (!ok)
                return BadRequest("Failed to finalize escrow");

            // Award bonus credits to giver
            var escrow = await _escrowService.GetEscrowByOfferIdAsync(offerId);
            if (escrow != null)
            {
                var giverBonus = escrow.GiverBonus;
                if (!giverBonus.HasValue || giverBonus.Value <= 0)
                {
                    var rateRaw = _config["Platform:GiverBonusRate"];
                    if (decimal.TryParse(
                            rateRaw,
                            NumberStyles.Number,
                            CultureInfo.InvariantCulture,
                            out var rate) &&
                        rate > 0)
                    {
                        giverBonus = Math.Round(escrow.Amount * rate, 2, MidpointRounding.AwayFromZero);
                        if (giverBonus > 0)
                        {
                            await _escrows.UpdateOneAsync(
                                e => e.Id == escrow.Id,
                                Builders<Escrow>.Update.Set(e => e.GiverBonus, giverBonus));
                        }
                    }
                }

                if (giverBonus.HasValue && giverBonus.Value > 0)
                {
                    await _rewardsService.AwardGiverBonusAsync(offer.UserId, giverBonus.Value);
                }
            }

            var update = Builders<Offer>.Update
                .Set(o => o.Status, "Active")
                .Set(o => o.CurrentBorrowerId, null)
                .Set(o => o.CompletedAt, DateTime.UtcNow);

            await _offers.UpdateOneAsync(o => o.OfferId == offerId, update);

            await SendRentalUpdateMessage(offer, giverId, "rental_completed", "Giver zakończył wypożyczenie");

            return Ok();
        }

        [Authorize]
        [HttpPost("claim/{offerId}")]
        public async Task<IActionResult> Claim(string offerId)
        {
            var giverId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(giverId))
                return Unauthorized();

            var offer = await _offers.Find(o => o.OfferId == offerId).FirstOrDefaultAsync();
            if (offer == null)
                return NotFound();

            if (!string.Equals(offer.UserId, giverId, StringComparison.Ordinal))
                return Forbid();

            var escrow = await _escrowService.GetEscrowByOfferIdAsync(offerId);
            if (escrow == null)
                return NotFound("Escrow not found");

            if (escrow.DeadlineAt.HasValue && escrow.DeadlineAt.Value > DateTime.UtcNow)
                return BadRequest("Deadline not reached yet");

            var ok = await _escrowService.ClaimEscrowAsync(
                offerId);

            if (!ok)
                return BadRequest("Failed to claim escrow");

            await _offers.UpdateOneAsync(
                o => o.OfferId == offerId,
                Builders<Offer>.Update
                    .Set(o => o.Status, "Active")
                    .Set(o => o.CompletedAt, DateTime.UtcNow));

            await SendRentalUpdateMessage(offer, giverId, "rental_claimed", "Kaucja została przejęta po przekroczeniu terminu");

            return Ok();
        }

        [Authorize]
        [HttpGet("escrow/{offerId}")]
        public async Task<IActionResult> GetEscrow(string offerId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var escrow = await _escrowService.GetEscrowByOfferIdAsync(offerId);
            if (escrow == null)
                return NotFound();

            if (escrow.BorrowerId != userId && escrow.LenderId != userId)
                return Forbid();

            return Ok(escrow);
        }

        [Authorize]
        [HttpGet("lender")]
        public async Task<IActionResult> GetLenderEscrows()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            
            if(string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var escrows = await _escrowService.GetEscrowsByLenderIdAsync(userId);

            if (escrows is null)
            {

                return NotFound();
            }

            return Ok(escrows);
        }

        [Authorize]
        [HttpGet("borrower")]
        public async Task<IActionResult> GetBorrowerEscrows()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if(string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var escrows = await _escrowService.GetEscrowsByBorrowerIdAsync(userId);

            if (escrows is null)
            {

                return NotFound();
            }

            return Ok(escrows);
        }

        private async Task<List<string>> UploadImagesAsync(List<IFormFile>? images, string userId)
        {
            var imageIds = new List<string>();
            if (_gridFS is null || images == null || images.Count == 0)
                return imageIds;

            foreach (var file in images)
            {
                if (file == null || file.Length == 0) continue;

                using var stream = file.OpenReadStream();
                var fileId = await _gridFS.UploadFromStreamAsync(
                    file.FileName,
                    stream,
                    new GridFSUploadOptions
                    {
                        Metadata = new BsonDocument
                        {
                            { "contentType", file.ContentType ?? "application/octet-stream" },
                            { "originalName", file.FileName },
                            { "userId", userId }
                        }
                    });

                imageIds.Add(fileId.ToString());
            }

            return imageIds;
        }

        private async Task SendRentalUpdateMessage(Offer offer, string senderId, string kind, string content)
        {
            if (string.IsNullOrWhiteSpace(offer.CurrentBorrowerId))
                return;

            var chat = await _chatService.CreateChatAsync(offer.OfferId, offer.CurrentBorrowerId, offer.UserId);
            if (chat == null)
                return;

            var payload = JsonSerializer.Serialize(new
            {
                offerId = offer.OfferId,
                offerKind = offer.OfferKind,
                deadlineAt = offer.RentalDeadlineAt,
                status = offer.Status,
                takerId = offer.CurrentBorrowerId,
                giverId = offer.UserId
            });

            await _chatService.SaveMessageAsync(chat.Id, senderId, content, kind, payload);
        }

        private decimal GetDecimalConfig(string key, decimal fallback)
        {
            var raw = _config[key];
            if (decimal.TryParse(raw, out var parsed))
                return parsed;
            return fallback;
        }
    }
}
