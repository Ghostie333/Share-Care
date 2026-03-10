using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using Share_Care.models;
using System.IO;
using Microsoft.Extensions.Logging;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserProfileController(IMongoDatabase database, ILogger<UserProfileController> logger) : ControllerBase
    {
        private readonly IMongoDatabase _database = database;
        private readonly GridFSBucket _bucket = new(database);
        private readonly IMongoCollection<UserData> _users = database.GetCollection<UserData>("users");
        private readonly ILogger<UserProfileController> _logger = logger;

        // Pobierz obraz: zwraca zawartość z GridFS
        [HttpGet("photo/{userId}")]
        public async Task<IActionResult> GetProfileImage(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
            {
                _logger.LogWarning("GetProfileImage wywołane z pustym userId");
                return BadRequest();
            }

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            if (user == null || string.IsNullOrEmpty(user.ProfileImageId))
            {
                _logger.LogWarning("Nie znaleziono obrazu dla użytkownika {UserId}", userId);
                return NotFound();
            }

            try
            {
                var fileId = new ObjectId(user.ProfileImageId);
                using var ms = new MemoryStream();
                await _bucket.DownloadToStreamAsync(fileId, ms);
                ms.Position = 0;

                // Spróbuj odczytać contentType z metadata
                var filesColl = _database.GetCollection<BsonDocument>("fs.files");
                var fileDoc = await filesColl.Find(Builders<BsonDocument>.Filter.Eq("_id", fileId)).FirstOrDefaultAsync();
                var contentType = fileDoc != null && fileDoc.Contains("metadata") && fileDoc["metadata"].AsBsonDocument.Contains("contentType")
                    ? fileDoc["metadata"]["contentType"].AsString
                    : "application/octet-stream";

                _logger.LogDebug("Pomyślnie pobrano obraz dla użytkownika {UserId}", userId);
                return File(ms.ToArray(), contentType);
            }
            catch (GridFSFileNotFoundException)
            {
                _logger.LogWarning("Plik GridFS nie istnieje dla użytkownika {UserId}, imageId: {ImageId}", 
                    userId, user.ProfileImageId);
                return NotFound();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania obrazu z GridFS dla użytkownika {UserId}", userId);
                return StatusCode(500);
            }
        }

        // Pobiera informacje o użytkowniku (imię, nazwisko, email, miasto)
        [HttpGet("info/{userId}")]
        public async Task<IActionResult> GetProfileInfo(string userId)
        {
            if (!ObjectId.TryParse(userId, out var objectId))
                return BadRequest("Invalid id");

            var filter = Builders<UserData>.Filter.Eq("_id", objectId);

            var user = await _users
                    .Find(filter)
                    .FirstOrDefaultAsync();

            if (user == null) return NotFound("User not found");

            try
            {
                return Ok(new { 
                    firstName = user.FirstName, 
                    lastName = user.LastName, 
                    email = user.Email, 
                    city = user.City 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać informacji o użytkowniku");
                return StatusCode(500);
            }
        }
    }
}