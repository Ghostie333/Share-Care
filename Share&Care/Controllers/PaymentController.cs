using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.Services;
using Share_Care.Models.Requests;
using Share_Care.models;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("payments")]
    public class PaymentController(IPaymentService paymentService) : ControllerBase
    {
        private readonly IPaymentService _paymentService = paymentService;

        [HttpPost("depostit")]
        public async Task<IActionResult> MakeDeposit(decimal amount)
        {
            await _paymentService.CreatePayUOrderAsync();
            return Ok();
        }
    }
}