using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Primitives;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Moq;
using Share_Care.models;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests
{
    public class LoginServiceTests
    {
        [Fact]
        public async Task ValidateCredentialsAsync_WithCorrectPassword_ReturnsUser()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "1",
                Email = "test@example.com",
                Password = Convert.ToBase64String(SecurityService.GetInstance().HashPassword("secret"))
            };

            var usersCollection = new Mock<IMongoCollection<UserData>>();
            var asyncCursor = new Mock<IAsyncCursor<UserData>>();
            asyncCursor.SetupSequence(c => c.MoveNext(It.IsAny<CancellationToken>()))
                .Returns(true)
                .Returns(false);
            asyncCursor.SetupGet(c => c.Current).Returns(new List<UserData> { user });

            usersCollection
                .Setup(c => c.FindAsync(
                    It.IsAny<FilterDefinition<UserData>>(),
                    It.IsAny<FindOptions<UserData, UserData>>(),
                    It.IsAny<CancellationToken>()))
                .ReturnsAsync(asyncCursor.Object);

            var db = new Mock<IMongoDatabase>();
            db.Setup(d => d.GetCollection<UserData>("users", null))
              .Returns(usersCollection.Object);

            var logger = new Mock<ILogger<LoginService>>();
            var security = SecurityService.GetInstance();
            var config = new ConfigurationBuilder().Build();

            var service = new LoginService(logger.Object, db.Object, security, config);

            // Act
            var result = await service.ValidateCredentialsAsync("test@example.com", "secret", CancellationToken.None);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("test@example.com", result!.Email);
        }

        [Fact]
        public void GenerateJwtToken_ReturnsTokenAndSetsExpiry()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "1",
                Email = "test@example.com",
                FirstName = "Test"
            };

            Environment.SetEnvironmentVariable("Auth__Jwt__Key", "very_secret_jwt_key_1234567890");

            var db = new Mock<IMongoDatabase>();
            var logger = new Mock<ILogger<LoginService>>();
            var security = SecurityService.GetInstance();
            var inMemorySettings = new Dictionary<string, string?>
            {
                { "Session:SessionTimeoutHours", "1" }
            };
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings!)
                .Build();

            var service = new LoginService(logger.Object, db.Object, security, config);

            // Act
            var token = service.GenerateJwtToken(user, out var expiresUtc);

            // Assert
            Assert.False(string.IsNullOrWhiteSpace(token));
            Assert.True(expiresUtc > DateTime.UtcNow);

            var handler = new JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(token);
            Assert.Equal("test@example.com", jwt.Payload[JwtRegisteredClaimNames.Email]);
        }
    }
}
