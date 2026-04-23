using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using MongoDB.Driver;
using Moq;
using Share_Care.Controllers;
using Share_Care.Models.Requests;
using Share_Care.models;
using Xunit;

namespace Share_Care.Tests.Controllers
{
    public class OfferControllerTests
    {
        [Fact]
        public async Task CreateOffer_WhenModelStateInvalid_ReturnsValidationProblem()
        {
            // Arrange
            var logger = new Mock<ILogger<OfferController>>();
            var db = new Mock<IMongoDatabase>();
            var controller = new OfferController(logger.Object, db.Object, gridFs: null)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
            };
            controller.ModelState.AddModelError("Title", "Required");

            // Act
            var result = await controller.CreateOffer(new CreateOfferRequest());

            // Assert
            Assert.IsType<ObjectResult>(result);
        }

        [Fact]
        public async Task CreateOffer_WhenOnlyLatProvided_ReturnsBadRequest()
        {
            // Arrange
            var logger = new Mock<ILogger<OfferController>>();
            var db = new Mock<IMongoDatabase>();
            var controller = CreateWithUser(logger.Object, db.Object, userId: "u1");

            var request = new CreateOfferRequest
            {
                Title = "t",
                ContactName = "c",
                Category = "cat",
                Lat = 10,
                Lng = null
            };

            // Act
            var result = await controller.CreateOffer(request);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);
        }

        [Fact]
        public async Task CreateOffer_WhenUserIdMissing_ReturnsUnauthorized()
        {
            // Arrange
            var logger = new Mock<ILogger<OfferController>>();
            var db = new Mock<IMongoDatabase>();
            var controller = new OfferController(logger.Object, db.Object, gridFs: null)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
            };

            var request = new CreateOfferRequest
            {
                Title = "t",
                ContactName = "c",
                Category = "cat"
            };

            // Act
            var result = await controller.CreateOffer(request);

            // Assert
            Assert.IsType<UnauthorizedResult>(result);
        }

        [Fact]
        public async Task GetAll_ReturnsOkWithPagedResponse()
        {
            // Arrange
            var logger = new Mock<ILogger<OfferController>>();

            var offers = new List<Offer>
            {
                new() { OfferId = "1", UserId = "u1", Title = "t", ContactName = "c", ContactNumber = "n", Category = "cat", CreatedAt = DateTime.UtcNow }
            };

            var offersCollection = new Mock<IMongoCollection<Offer>>();
            var asyncCursor = new Mock<IAsyncCursor<Offer>>();
            asyncCursor.SetupSequence(c => c.MoveNextAsync(It.IsAny<CancellationToken>()))
                .ReturnsAsync(true)
                .ReturnsAsync(false);
            asyncCursor.SetupGet(c => c.Current).Returns(offers);

            offersCollection
                .Setup(c => c.FindAsync(
                    It.IsAny<FilterDefinition<Offer>>(),
                    It.IsAny<FindOptions<Offer, Offer>>(),
                    It.IsAny<CancellationToken>()))
                .ReturnsAsync(asyncCursor.Object);

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<Offer>("offers", null)).Returns(offersCollection.Object);
            var controller = new OfferController(logger.Object, db.Object, gridFs: null)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
            };

            // Act
            var result = await controller.GetAll(new OfferFiltersRequest(), page: 1, limit: 20);

            // Assert
            var ok = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(ok.Value);
        }

        private static OfferController CreateWithUser(ILogger<OfferController> logger, IMongoDatabase db, string userId)
        {
            var http = new DefaultHttpContext();
            http.User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(ClaimTypes.NameIdentifier, userId) },
                authenticationType: "Test"));

            return new OfferController(logger, db, gridFs: null)
            {
                ControllerContext = new ControllerContext { HttpContext = http }
            };
        }
    }
}
