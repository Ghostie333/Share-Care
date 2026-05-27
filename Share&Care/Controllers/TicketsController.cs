using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("tickets")]
    public class TicketsController(IMongoDatabase db, ILogger<TicketsController> logger) : ControllerBase
    {
        private readonly IMongoCollection<Ticket> _tickets = db.GetCollection<Ticket>("tickets");
        private readonly ILogger<TicketsController> _logger = logger;

        [Authorize]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateTicketRequest request)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            try
            {
                var ticket = new Ticket
                {
                    UserId = userId,
                    ListingId = string.IsNullOrWhiteSpace(request.ListingId) ? null : request.ListingId,
                    ChatId = string.IsNullOrWhiteSpace(request.ChatId) ? null : request.ChatId,
                    TargetUserId = string.IsNullOrWhiteSpace(request.TargetUserId) ? null : request.TargetUserId,
                    Reason = request.Reason!.Trim(),
                    Description = request.Description!.Trim(),
                    Status = "Open",
                    CreatedAt = DateTime.UtcNow
                };

                await _tickets.InsertOneAsync(ticket);

                return Ok(new { id = ticket.Id, status = ticket.Status });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create ticket");
                return StatusCode(StatusCodes.Status500InternalServerError);
            }
        }

        [Authorize]
        [HttpGet("my")]
        public async Task<IActionResult> GetMy()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var tickets = await _tickets
                .Find(t => t.UserId == userId)
                .SortByDescending(t => t.CreatedAt)
                .ToListAsync();

            return Ok(tickets);
        }
    }
}
