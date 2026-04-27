using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using Share_Care.models;
using Share_Care.Services;
using System.IO;
using Microsoft.Extensions.Logging;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Share_Care.Models.Requests;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserProfileController(IMongoDatabase database, ILogger<UserProfileController> logger, SecurityService securityService) : ControllerBase
    {
        private readonly IMongoDatabase _database = database;
        private readonly GridFSBucket _bucket = new(database);
        private readonly IMongoCollection<UserData> _users = database.GetCollection<UserData>("users");
        private readonly ILogger<UserProfileController> _logger = logger;
        private readonly SecurityService _security = securityService;

        // Prosty 1x1 przezroczysty PNG (unikamy 404, gdy brak zdjęcia)
        private static readonly byte[] _emptyPng = Convert.FromBase64String(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=");

        // Pobierz obraz: zwraca zawartość z GridFS
        [HttpGet("photo/{userId}")]
        public async Task<IActionResult> GetProfileImage(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
            {
                _logger.LogWarning("GetProfileImage wywołane z pustym userId");
                // Zwracamy pusty obraz zamiast 400, żeby uniknąć błędów w kliencie.
                return File(_emptyPng, "image/png");
            }

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            if (user == null)
            {
                _logger.LogWarning("Nie znaleziono użytkownika {UserId} przy pobieraniu zdjęcia", userId);
                // Dla spójności po stronie frontendu również zwracamy pusty obraz.
                return File(_emptyPng, "image/png");
            }

            if (string.IsNullOrEmpty(user.ProfileImageId))
            {
                // Brak zdjęcia profilowego – zwracamy pusty obraz zamiast 404,
                // aby frontend (NetworkImage) nie zgłaszał błędów.
                _logger.LogDebug("Użytkownik {UserId} nie ma ustawionego zdjęcia profilowego", userId);
                return File(_emptyPng, "image/png");
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
                // Zwracamy pusty obraz zamiast 404.
                return File(_emptyPng, "image/png");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania obrazu z GridFS dla użytkownika {UserId}", userId);
                return StatusCode(500);
            }
        }

        // Prześlij / zaktualizuj zdjęcie profilowe aktualnie zalogowanego użytkownika
        [Authorize]
        [HttpPost("photo")]
        public async Task<IActionResult> UploadProfileImage([FromForm] IFormFile file)
        {
            var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(currentUserId))
            {
                return Unauthorized();
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest("Brak pliku do przesłania.");
            }

            var user = await _users.Find(u => u.UserId == currentUserId).FirstOrDefaultAsync();
            if (user == null)
            {
                return NotFound("User not found");
            }

            try
            {
                // Usuń poprzedni obraz jeśli istnieje
                if (!string.IsNullOrEmpty(user.ProfileImageId))
                {
                    if (ObjectId.TryParse(user.ProfileImageId, out var oldId))
                    {
                        await _bucket.DeleteAsync(oldId);
                    }
                }

                // Zapisz nowy obraz w GridFS
                ObjectId newId;
                await using (var stream = file.OpenReadStream())
                {
                    newId = await _bucket.UploadFromStreamAsync(
                        file.FileName,
                        stream,
                        new GridFSUploadOptions
                        {
                            Metadata = new BsonDocument
                            {
                                { "contentType", file.ContentType }
                            }
                        });
                }

                var update = Builders<UserData>.Update
                    .Set(u => u.ProfileImageId, newId.ToString());

                await _users.UpdateOneAsync(u => u.UserId == currentUserId, update);

                return Ok("Profile image updated.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd zapisu zdjęcia profilowego dla użytkownika {UserId}", currentUserId);
                return StatusCode(500);
            }
        }

        // Pobiera informacje o użytkowniku (imię, nazwisko, email, miasto, telefon, typ, ocena)
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
                return Ok(new
                {
                    firstName = user.FirstName,
                    lastName = user.LastName,
                    email = user.Email,
                    city = user.City,
                    postalCode = user.PostalCode,
                    street = user.Street,
                    buildingNumber = user.BuildingNumber,
                    phoneNumber = user.PhoneNumber,
                    raiting = user.Raiting,
                    type = user.Type
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać informacji o użytkowniku");
                return StatusCode(500);
            }
        }

        // Aktualizacja profilu użytkownika
        [Authorize]
        [HttpPut("update-profile")]
        public async Task<IActionResult> UpdateUserProfile([FromBody] UserUpdateRequest form)
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var update = Builders<UserData>.Update
                    .Set(x => x.Brithday, form.Birthday)
                    .Set(x => x.City, form.City)
                    .Set(x => x.PostalCode, form.PostalCode)
                    .Set(x => x.Street, form.Street)
                    .Set(x => x.BuildingNumber, form.BuildingNumber)
                    .Set(x => x.FirstName, form.FirstName)
                    .Set(x => x.LastName, form.LastName)
                    .Set(x => x.Email, form.Email)
                    .Set(x => x.PhoneNumber, form.PhoneNumber);

                await _users.FindOneAndUpdateAsync(x => x.UserId == currentUserId, update);

                return Ok("Pomyślnie zaktualizowano profil użytkownika");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się zaktualizować informacji o użytkowniku");
                return StatusCode(500);
            }
        }

        // Zmiana hasła aktualnie zalogowanego użytkownika
        [Authorize]
        [HttpPost("change-password")]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var user = await _users.Find(u => u.UserId == currentUserId).FirstOrDefaultAsync();
                if (user == null || string.IsNullOrWhiteSpace(user.Password))
                {
                    return NotFound("User not found");
                }

                var ok = _security.ComparePasswords(request.CurrentPassword ?? string.Empty, user.Password);
                if (!ok)
                {
                    return BadRequest("Obecne hasło jest nieprawidłowe.");
                }

                var newHashBytes = _security.HashPassword(request.NewPassword ?? string.Empty);
                var newHash = Convert.ToBase64String(newHashBytes);

                var update = Builders<UserData>.Update
                    .Set(u => u.Password, newHash);

                await _users.UpdateOneAsync(u => u.UserId == currentUserId, update);

                return Ok("Password changed.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się zmienić hasła użytkownika");
                return StatusCode(500);
            }
        }

        // Usunięcie profilu użytkownika wraz z danymi
        [Authorize]
        [HttpDelete("delete-profile")]
        public async Task<IActionResult> DeleteUserProfile()
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var deleteResult = await _users.DeleteOneAsync(x => x.UserId == currentUserId);

                if (deleteResult.DeletedCount == 0)
                {
                    return NotFound("User not found");
                }

                return Ok("Pomyślnie usunięto profil użytkownika");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się usunąć profilu użytkownika");
                return StatusCode(500);
            }
        }
    }
}