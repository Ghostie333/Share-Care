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
    public class UserProfileController : ControllerBase
    {
        private readonly IMongoDatabase _database;
        private readonly GridFSBucket _bucket;
        private readonly IMongoCollection<UserData> _users;
        private readonly ILogger<UserProfileController> _logger;

        public UserProfileController(IMongoDatabase database, ILogger<UserProfileController> logger)
        {
            _database = database;
            _bucket = new GridFSBucket(_database);
            _users = _database.GetCollection<UserData>("users");
            _logger = logger;
        }

        // Pobierz obraz: zwraca zawartość z GridFS
        [HttpGet("photo/{userId}")]
        public async Task<IActionResult> GetProfileImage(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId)) return BadRequest();

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            if (user == null || string.IsNullOrEmpty(user.ProfileImageId)) return NotFound();

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

                return File(ms.ToArray(), contentType);
            }
            catch (GridFSFileNotFoundException)
            {
                return NotFound();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania obrazu z GridFS");
                return StatusCode(500);
            }
        }
    }
}