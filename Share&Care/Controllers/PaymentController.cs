using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.Services;
using Share_Care.models.requests;
using Share_Care.models;
using System.Security.Claims;
using System.Text;
using System.Text.Json;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("payments")]
    public class PaymentController(IPaymentService paymentService,
        ITransactionService transactionService,
        IConfiguration config,
        ILogger<PaymentController> logger) : ControllerBase
    {
        private readonly IPaymentService _paymentService = paymentService;
        private readonly ITransactionService _transactionService = transactionService;
        private readonly IConfiguration _config = config;
        private readonly ILogger<PaymentController> _logger = logger;

        [Authorize]
        [HttpPost("deposit")]
        public async Task<IActionResult> MakeDeposit(decimal amount)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            var transaction = await _transactionService.CreateTransactionAsync(new Transaction
            {
                UserId = userId,
                Amount = amount,
                Type = "Deposit",
                Status = "Pending"
            });

            var redirectUrl = await _paymentService.CreatePayUOrderAsync(transaction);

            return Ok(new { redirectUrl });
        }

        [AllowAnonymous]
        [HttpPost("webhook")]
        public async Task<IActionResult> HandleWebhook()
        {
            // Czytanie surowego body
            Request.EnableBuffering();
            using var reader = new StreamReader(Request.Body, Encoding.UTF8, leaveOpen: true);
            var rawBody = await reader.ReadToEndAsync();
            Request.Body.Position = 0;

            var signatureHeader = Request.Headers["OpenPayU-Signature"].ToString();
            var secondKey = _config["PayU:SecondKey"];

            _logger.LogInformation("Webhook raw body: {Body}", rawBody);
            _logger.LogInformation("Signature: {Sig}", signatureHeader);

            var isValid = _paymentService.ValidateWebhookSignature(signatureHeader, rawBody, secondKey);

            if (!isValid)
                return Unauthorized();

            var externalId = JsonSerializer.Deserialize<PayUWebhookPayload>(rawBody)?.Order?.OrderId;

            if (string.IsNullOrWhiteSpace(externalId))
                return BadRequest("Missing externalId");

            var transaction = await _transactionService.GetTransactionByExternalIdAsync(externalId);

            if (transaction == null)
                return NotFound();

            if (transaction.Status == "Completed")
                return Ok();

            var status = JsonSerializer.Deserialize<PayUWebhookPayload>(rawBody)!.Order!.Status;

            if(status == "COMPLETED")
            {
                await _paymentService.ProcessSuccessfulPayment(transaction);
            }
            else if (status == "CANCELED")
            {
                await _paymentService.ProcessFailedPayment(transaction);
            }

            return Ok();
        }
    }
}