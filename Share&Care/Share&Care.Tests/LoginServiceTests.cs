using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
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
        private readonly SecurityService _securityService = new SecurityService();
        [Fact]
        public async Task ValidateCredentialsAsync_WithCorrectPassword_ReturnsUser()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "1",
                Email = "test@example.com",
                Password = Convert.ToBase64String(_securityService.HashPassword("secret"))
            };

            var usersCollection = new Mock<IMongoCollection<UserData>>();
            var asyncCursor = new Mock<IAsyncCursor<UserData>>();
            asyncCursor.SetupSequence(c => c.MoveNext(It.IsAny<CancellationToken>()))
                .Returns(true)
                .Returns(false);
            asyncCursor.SetupSequence(c => c.MoveNextAsync(It.IsAny<CancellationToken>()))
                .ReturnsAsync(true)
                .ReturnsAsync(false);
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
            var config = new ConfigurationBuilder().Build();

            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            var result = await service.ValidateCredentialsAsync("test@example.com", "secret", CancellationToken.None);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("test@example.com", result!.Email);
        }

        [Fact]
        public async Task ValidateCredentialsAsync_WhenUserNotFound_ReturnsNull()
        {
            // Arrange
            var usersCollection = new Mock<IMongoCollection<UserData>>();
            var asyncCursor = new Mock<IAsyncCursor<UserData>>();
            asyncCursor.SetupSequence(c => c.MoveNextAsync(It.IsAny<CancellationToken>()))
                .ReturnsAsync(false);
            asyncCursor.SetupGet(c => c.Current).Returns(Array.Empty<UserData>());

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
            var config = new ConfigurationBuilder().Build();
            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            var result = await service.ValidateCredentialsAsync("missing@example.com", "secret", CancellationToken.None);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task ValidateCredentialsAsync_WithWrongPassword_ReturnsNull()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "1",
                Email = "test@example.com",
                Password = Convert.ToBase64String(_securityService.HashPassword("secret"))
            };

            var usersCollection = new Mock<IMongoCollection<UserData>>();
            var asyncCursor = new Mock<IAsyncCursor<UserData>>();
            asyncCursor.SetupSequence(c => c.MoveNextAsync(It.IsAny<CancellationToken>()))
                .ReturnsAsync(true)
                .ReturnsAsync(false);
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
            var config = new ConfigurationBuilder().Build();
            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            var result = await service.ValidateCredentialsAsync("test@example.com", "wrong", CancellationToken.None);

            // Assert
            Assert.Null(result);
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

            Environment.SetEnvironmentVariable("Auth__Jwt__Key", "very_secret_jwt_key_1234567890_12");

            var db = new Mock<IMongoDatabase>();
            var logger = new Mock<ILogger<LoginService>>();
            var inMemorySettings = new Dictionary<string, string?>
            {
                { "Session:SessionTimeoutHours", "1" }
            };
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings!)
                .Build();

            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            var token = service.GenerateJwtToken(user, out var expiresUtc);

            // Assert
            Assert.False(string.IsNullOrWhiteSpace(token));
            Assert.True(expiresUtc > DateTime.UtcNow);

            var handler = new JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(token);
            Assert.Equal("test@example.com", jwt.Payload[JwtRegisteredClaimNames.Email]);
        }

        [Fact]
        public void GenerateJwtToken_WhenKeyMissing_Throws()
        {
            // Arrange
            Environment.SetEnvironmentVariable("Auth__Jwt__Key", null);
            var user = new UserData { UserId = "1", Email = "test@example.com", FirstName = "Test" };

            var db = new Mock<IMongoDatabase>();
            var logger = new Mock<ILogger<LoginService>>();
            var config = new ConfigurationBuilder().Build();
            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act + Assert
            Assert.Throws<InvalidOperationException>(() => service.GenerateJwtToken(user, out _));
        }

        [Fact]
        public void GenerateJwtToken_UsesSessionTimeoutFromConfig()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "1",
                Email = "test@example.com",
                FirstName = "Test"
            };

            Environment.SetEnvironmentVariable("Auth__Jwt__Key", "very_secret_jwt_key_1234567890_12");

            var db = new Mock<IMongoDatabase>();
            var logger = new Mock<ILogger<LoginService>>();
            var inMemorySettings = new Dictionary<string, string?>
            {
                { "Session:SessionTimeoutHours", "2" }
            };
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings!)
                .Build();

            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            _ = service.GenerateJwtToken(user, out var expiresUtc);

            // Assert
            var diff = expiresUtc - DateTime.UtcNow;
            Assert.True(diff > TimeSpan.FromHours(1.8) && diff < TimeSpan.FromHours(2.2));
        }

        [Fact]
        public void GenerateJwtToken_ContainsExpectedClaims()
        {
            // Arrange
            var user = new UserData
            {
                UserId = "123",
                Email = "test@example.com",
                FirstName = "Test"
            };

            Environment.SetEnvironmentVariable("Auth__Jwt__Key", "very_secret_jwt_key_1234567890_12");

            var db = new Mock<IMongoDatabase>();
            var logger = new Mock<ILogger<LoginService>>();
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?> { { "Session:SessionTimeoutHours", "1" } })
                .Build();

            var service = new LoginService(logger.Object, db.Object, _securityService, config);

            // Act
            var token = service.GenerateJwtToken(user, out _);

            // Assert
            var handler = new JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(token);
            var subject = jwt.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Sub)?.Value;
            var email = jwt.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Email)?.Value;

            Assert.Equal("123", subject);
            Assert.Equal("test@example.com", email);
        }
    }
}
