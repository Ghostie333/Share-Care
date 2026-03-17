using System;
using System.Text;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests
{
    public class SecurityServiceTests
    {
        private readonly SecurityService _securityService = new SecurityService();
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

        [Fact]
        public void HashPassword_SamePasswordTwice_ProducesDifferentHashes()
        {
            // Arrange
            const string password = "P@ssw0rd!";

            // Act
            var hash1 = Convert.ToBase64String(_securityService.HashPassword(password));
            var hash2 = Convert.ToBase64String(_securityService.HashPassword(password));

            // Assert
            Assert.NotEqual(hash1, hash2);
        }

        [Fact]
        public void ComparePasswords_WhenHashedPasswordIsNotBase64_Throws()
        {
            // Arrange
            const string password = "P@ssw0rd!";
            const string notBase64 = "this-is-not-base64";

            // Act + Assert
            Assert.Throws<FormatException>(() => _securityService.ComparePasswords(password, notBase64));
        }
    }
}
