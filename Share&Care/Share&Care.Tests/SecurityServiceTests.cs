using System;
using System.Text;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests
{
    public class SecurityServiceTests(SecurityService securityService)
    {
        private readonly SecurityService _securityService = securityService;
        [Fact]
        public void HashPassword_And_ComparePasswords_WithCorrectPassword_ReturnsTrue()
        {
            // Arrange
            const string password = "P@ssw0rd!";

            // Act
            var hashBytes = _securityService.HashPassword(password);
            var hashBase64 = Convert.ToBase64String(hashBytes);
            var result = _securityService.ComparePasswords(password, hashBase64);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void ComparePasswords_WithWrongPassword_ReturnsFalse()
        {
            // Arrange
            const string password = "P@ssw0rd!";
            const string otherPassword = "other";

            var hashBytes = _securityService.HashPassword(password);
            var hashBase64 = Convert.ToBase64String(hashBytes);

            // Act
            var result = _securityService.ComparePasswords(otherPassword, hashBase64);

            // Assert
            Assert.False(result);
        }
    }
}
