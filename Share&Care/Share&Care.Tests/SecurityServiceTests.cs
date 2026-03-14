using System;
using System.Text;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests
{
    public class SecurityServiceTests
    {
        [Fact]
        public void HashPassword_And_ComparePasswords_WithCorrectPassword_ReturnsTrue()
        {
            // Arrange
            var security = SecurityService.GetInstance();
            const string password = "P@ssw0rd!";

            // Act
            var hashBytes = security.HashPassword(password);
            var hashBase64 = Convert.ToBase64String(hashBytes);
            var result = security.ComparePasswords(password, hashBase64);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void ComparePasswords_WithWrongPassword_ReturnsFalse()
        {
            // Arrange
            var security = SecurityService.GetInstance();
            const string password = "P@ssw0rd!";
            const string otherPassword = "other";

            var hashBytes = security.HashPassword(password);
            var hashBase64 = Convert.ToBase64String(hashBytes);

            // Act
            var result = security.ComparePasswords(otherPassword, hashBase64);

            // Assert
            Assert.False(result);
        }
    }
}
