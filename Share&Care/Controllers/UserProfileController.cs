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

        // Upload: multipart/form-data, pole "file" i "userId"
        #region FunkcjaDoPrzesłaniaZdjęciaProfilowego(Nie Działa)
        /*
        [HttpPost("upload")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UploadProfileImage([FromForm] IFormFile file, [FromForm] string userId)
        {
            throw new NotImplementedException("Funkcja uploadu obrazu profilu została wyłączona.");
            #region PowodujeBłąd
            //if (file == null || file.Length == 0) return BadRequest("Brak pliku.");
            //if (string.IsNullOrWhiteSpace(userId)) return BadRequest("Brak userId.");

            //try
            //{
            //    using var ms = new MemoryStream();
            //    await file.CopyToAsync(ms);
            //    var bytes = ms.ToArray();
            //    var filename = $"{userId}_{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";

            //    var options = new GridFSUploadOptions
            //    {
            //        Metadata = new BsonDocument { { "contentType", file.ContentType } }
            //    };

            //    var objectId = await _bucket.UploadFromBytesAsync(filename, bytes, options);
            //    var idString = objectId.ToString();

            //    var filter = Builders<UserData>.Filter.Eq(u => u.UserId, userId);
            //    var update = Builders<UserData>.Update.Set(u => u.ProfileImageId, idString);
            //    await _users.UpdateOneAsync(filter, update);

            //    return Ok(new { profileImageId = idString });
            //}
            //catch (Exception ex)
            //{
            //    _logger.LogError(ex, "Błąd uploadu profilu");
            //    return StatusCode(500, "Błąd serwera podczas zapisu pliku.");
            //}
            #endregion
        }
        */
        #endregion

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