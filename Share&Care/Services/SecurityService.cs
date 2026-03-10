using SharpCompress.Common;
using System.Security.Cryptography;

namespace Share_Care.Services
{
    public class SecurityService
    {
        private const int _saltLength = 16;
        private const int _hashLength = 20;

        public byte[] HashPassword(string password)
        {
            byte[] salt;
            new RNGCryptoServiceProvider().GetBytes(salt = new byte[_saltLength]);

            var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 100000);
            byte[] hash = pbkdf2.GetBytes(_hashLength);

            byte[] hashBytes = new byte[_saltLength + _hashLength];
            Array.Copy(salt, 0, hashBytes, 0, _saltLength);
            Array.Copy(hash, 0, hashBytes, _saltLength, _hashLength);

            return hashBytes;
        }

        public bool ComparePasswords(string password, string hashedPassword)
        {
            byte[] hashBytes = Convert.FromBase64String(hashedPassword);
            byte[] salt = new byte[_saltLength];

            Array.Copy(hashBytes, 0, salt, 0, _saltLength);

            var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 100000);
            var newHash = pbkdf2.GetBytes(_hashLength);

            for (int i = 0; i < 20; i++)
            {
                if (hashBytes[i + _saltLength] != newHash[i])
                {
                    return false;
                }
            }

            return true;
        }
    }
}