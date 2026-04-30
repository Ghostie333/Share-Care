using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.Services;
using Share_Care.models.requests;
using Share_Care.models;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("payments")]
    public class PaymentController(IPaymentService paymentService,
        ITransactionService transactionService) : ControllerBase
    {
        private readonly IPaymentService _paymentService = paymentService;
        private readonly ITransactionService _transactionService = transactionService;

        [HttpPost("depostit")]
        public async Task<IActionResult> MakeDeposit(decimal amount)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            var transaction = await _transactionService.CreateTransactionAsync(new models.Transaction
            {
                UserId = userId,
                Amount = amount,
                Type = "Deposit",
                Status = "Pending"
            });

            var redirectUrl = await _paymentService.CreatePayUOrderAsync(transaction);

            return Ok(new { redirectUrl });
        }

        [HttpPost("webhook")]
        public async Task<IActionResult> HandleWebhook([FromBody] PayUWebhookPayload payload)
        {
            var isValid = _paymentService.ValidateWebhookSignature();

            if (!isValid)
                return Unauthorized();

            var externalId = payload?.Order?.OrderId;

            if (string.IsNullOrWhiteSpace(externalId))
                return BadRequest("Missing externalId");

            var transaction = await _transactionService.GetTransactionByExternalIdAsync(externalId);

            if (transaction == null)
                return NotFound();

            if (transaction.Status == "Completed")
                return Ok();

            var status = payload!.Order!.Status;

            if(status == "Completed")
            {
                await _paymentService.ProcessSuccessfulPayment(transaction);
            }
            else if (status == "Failed")
            {
                await _paymentService.ProcessFailedPayment(transaction);
            }

            return Ok();
        }
    }
}