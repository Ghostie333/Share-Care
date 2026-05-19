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
    public class UserProfileController(IMongoDatabase database, ILogger<UserProfileController> logger, SecurityService securityService, IWalletService walletService) : ControllerBase
    {
        private readonly IMongoDatabase _database = database;
        private readonly GridFSBucket _bucket = new(database);
        private readonly IMongoCollection<UserData> _users = database.GetCollection<UserData>("users");
        private readonly IMongoCollection<Offer> _offers = database.GetCollection<Offer>("offers");
        private readonly IMongoCollection<Escrow> _escrows = database.GetCollection<Escrow>("escrows");
        private readonly ILogger<UserProfileController> _logger = logger;
        private readonly SecurityService _security = securityService;
        private readonly IWalletService _walletService = walletService;

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
                var userOffers = await _offers
                    .Find(o => o.UserId == user.UserId)
                    .ToListAsync();
                var offersForStats = userOffers
                    .Where(o => !IsReport(o))
                    .ToList();
                var activeOffers = offersForStats
                    .Where(o => string.Equals(o.Status, "Active", StringComparison.OrdinalIgnoreCase))
                    .ToList();
                var completedOffers = offersForStats
                    .Where(o => string.Equals(o.Status, "Completed", StringComparison.OrdinalIgnoreCase))
                    .ToList();
                var differentCitiesCount = offersForStats
                    .Select(o => string.IsNullOrWhiteSpace(o.LocationText) ? string.Empty : o.LocationText.Trim().ToLowerInvariant())
                    .Where(city => !string.IsNullOrWhiteSpace(city))
                    .Distinct()
                    .Count();
                var giveOffersCount = offersForStats.Count(o => string.Equals(o.OfferKind, "Give", StringComparison.OrdinalIgnoreCase));
                var negotiationsCount = await _escrows.CountDocumentsAsync(
                    e => e.BorrowerId == user.UserId || e.LenderId == user.UserId);
                var firstDayPurchasesCount = await CountFirstDayPurchasesAsync(user.UserId ?? string.Empty);
                var wallet = await _walletService.GetWalletByUserIdAsync(user.UserId ?? string.Empty);
                return Ok(new
                {
                    brithday = user.Brithday,
                    firstName = user.FirstName,
                    lastName = user.LastName,
                    email = user.Email,
                    city = user.City,
                    postalCode = user.PostalCode,
                    street = user.Street,
                    buildingNumber = user.BuildingNumber,
                    phoneNumber = user.PhoneNumber,
                    raiting = user.Raiting,
                    ratingCount = user.RatingCount,
                    credits = user.Credits,
                    showFirstName = user.ShowFirstName,
                    showLastName = user.ShowLastName,
                    showCity = user.ShowCity,
                    showPhoneNumber = user.ShowPhoneNumber,
                    showProfileImage = user.ShowProfileImage,
                    offersCount = offersForStats.Count,
                    activeOffersCount = activeOffers.Count,
                    completedCount = completedOffers.Count,
                    negotiationsCount,
                    giveOffersCount,
                    firstDayPurchasesCount,
                    differentCitiesCount,
                    loweredPriceChangesCount = user.LoweredPriceChangesCount,
                    walletBalance = wallet?.Balance ?? 0m,
                    walletLocked = wallet?.LockedBalance ?? 0m,
                    type = user.Type
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać informacji o użytkowniku");
                return StatusCode(500);
            }
        }

        [HttpGet("public/{userId}")]
        public async Task<IActionResult> GetPublicProfile(string userId)
        {
            if (!ObjectId.TryParse(userId, out var objectId))
                return BadRequest("Invalid id");

            var filter = Builders<UserData>.Filter.Eq("_id", objectId);
            var user = await _users.Find(filter).FirstOrDefaultAsync();
            if (user == null) return NotFound("User not found");

            var userOffers = await _offers
                .Find(o => o.UserId == user.UserId)
                .ToListAsync();
            var offersForStats = userOffers
                .Where(o => !IsReport(o))
                .ToList();
            var reportOffers = userOffers
                .Where(o => IsReport(o))
                .ToList();
            var activeOffers = offersForStats
                .Where(o => string.Equals(o.Status, "Active", StringComparison.OrdinalIgnoreCase))
                .ToList();
            var activeReports = reportOffers
                .Where(o => string.Equals(o.Status, "Active", StringComparison.OrdinalIgnoreCase))
                .ToList();
            var completedOffersAll = offersForStats
                .Where(o => string.Equals(o.Status, "Completed", StringComparison.OrdinalIgnoreCase))
                .ToList();
            var completedOffers = completedOffersAll
                .OrderByDescending(o => o.CompletedAt)
                .Take(10)
                .ToList();
            var differentCitiesCount = offersForStats
                .Select(o => string.IsNullOrWhiteSpace(o.LocationText) ? string.Empty : o.LocationText.Trim().ToLowerInvariant())
                .Where(city => !string.IsNullOrWhiteSpace(city))
                .Distinct()
                .Count();
            var giveOffersCount = offersForStats.Count(o => string.Equals(o.OfferKind, "Give", StringComparison.OrdinalIgnoreCase));
            var negotiationsCount = await _escrows.CountDocumentsAsync(
                e => e.BorrowerId == user.UserId || e.LenderId == user.UserId);
            var firstDayPurchasesCount = await CountFirstDayPurchasesAsync(user.UserId ?? string.Empty);

            var rank = ResolveRank(user.Credits, user.Raiting);

            var firstName = user.ShowFirstName ? user.FirstName : string.Empty;
            var lastName = user.ShowLastName ? user.LastName : string.Empty;
            var city = user.ShowCity ? user.City : string.Empty;
            var phoneNumber = user.ShowPhoneNumber ? user.PhoneNumber : string.Empty;

            return Ok(new
            {
                userId = user.UserId,
                firstName,
                lastName,
                city,
                phoneNumber,
                raiting = user.Raiting,
                ratingCount = user.RatingCount,
                showFirstName = user.ShowFirstName,
                showLastName = user.ShowLastName,
                showCity = user.ShowCity,
                showPhoneNumber = user.ShowPhoneNumber,
                showProfileImage = user.ShowProfileImage,
                offersCount = offersForStats.Count,
                activeOffersCount = activeOffers.Count,
                activeReportsCount = activeReports.Count,
                    completedCount = completedOffersAll.Count,
                negotiationsCount,
                giveOffersCount,
                firstDayPurchasesCount,
                differentCitiesCount,
                loweredPriceChangesCount = user.LoweredPriceChangesCount,
                rank,
                activeOffers = activeOffers.Select(o => new
                {
                    offerId = o.OfferId,
                    title = o.Title,
                    category = o.Category,
                    deposit = o.Deposit,
                    offerKind = o.OfferKind,
                    locationText = o.LocationText,
                    imageIds = o.ImageIds,
                }),
                activeReports = activeReports.Select(o => new
                {
                    offerId = o.OfferId,
                    title = o.Title,
                    category = o.Category,
                    deposit = o.Deposit,
                    offerKind = o.OfferKind,
                    locationText = o.LocationText,
                    imageIds = o.ImageIds,
                }),
                offers = activeOffers.Select(o => new
                {
                    offerId = o.OfferId,
                    title = o.Title,
                    category = o.Category,
                    deposit = o.Deposit,
                    offerKind = o.OfferKind,
                    locationText = o.LocationText,
                    imageIds = o.ImageIds,
                }),
                completedHistory = completedOffers.Select(o => new
                {
                    offerId = o.OfferId,
                    title = o.Title,
                    category = o.Category,
                    completedAt = o.CompletedAt,
                    offerKind = o.OfferKind
                })
            });
        }

        [Authorize]
        [HttpPost("rate/{userId}")]
        public async Task<IActionResult> RateUser(string userId, [FromBody] RateUserRequest request)
        {
            if (request.Score < 0 || request.Score > 5)
                return BadRequest("Score must be between 0 and 5");

            if (!ObjectId.TryParse(userId, out var objectId))
                return BadRequest("Invalid id");

            var filter = Builders<UserData>.Filter.Eq("_id", objectId);
            var user = await _users.Find(filter).FirstOrDefaultAsync();
            if (user == null)
                return NotFound("User not found");

            var currentRating = user.Raiting ?? 0f;
            var currentCount = user.RatingCount;
            var newCount = currentCount + 1;
            var newRating = ((currentRating * currentCount) + request.Score) / newCount;

            var update = Builders<UserData>.Update
                .Set(u => u.Raiting, newRating)
                .Set(u => u.RatingCount, newCount);

            await _users.UpdateOneAsync(filter, update);

            return Ok(new { raiting = newRating, ratingCount = newCount });
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

                var updates = new List<UpdateDefinition<UserData>>
                {
                    Builders<UserData>.Update.Set(x => x.Brithday, form.Birthday),
                    Builders<UserData>.Update.Set(x => x.City, form.City),
                    Builders<UserData>.Update.Set(x => x.PostalCode, form.PostalCode),
                    Builders<UserData>.Update.Set(x => x.Street, form.Street),
                    Builders<UserData>.Update.Set(x => x.BuildingNumber, form.BuildingNumber),
                    Builders<UserData>.Update.Set(x => x.FirstName, form.FirstName),
                    Builders<UserData>.Update.Set(x => x.LastName, form.LastName),
                    Builders<UserData>.Update.Set(x => x.Email, form.Email),
                    Builders<UserData>.Update.Set(x => x.PhoneNumber, form.PhoneNumber)
                };

                if (form.ShowFirstName.HasValue)
                    updates.Add(Builders<UserData>.Update.Set(x => x.ShowFirstName, form.ShowFirstName.Value));
                if (form.ShowLastName.HasValue)
                    updates.Add(Builders<UserData>.Update.Set(x => x.ShowLastName, form.ShowLastName.Value));
                if (form.ShowCity.HasValue)
                    updates.Add(Builders<UserData>.Update.Set(x => x.ShowCity, form.ShowCity.Value));
                if (form.ShowPhoneNumber.HasValue)
                    updates.Add(Builders<UserData>.Update.Set(x => x.ShowPhoneNumber, form.ShowPhoneNumber.Value));
                if (form.ShowProfileImage.HasValue)
                    updates.Add(Builders<UserData>.Update.Set(x => x.ShowProfileImage, form.ShowProfileImage.Value));

                await _users.FindOneAndUpdateAsync(x => x.UserId == currentUserId, Builders<UserData>.Update.Combine(updates));

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

        private static string ResolveRank(int credits, float? rating)
        {
            if (credits >= 5000 && (rating ?? 0) >= 4.5f) return "Mistrz";
            if (credits >= 2000) return "Ekspert";
            if (credits >= 500) return "Zaawansowany";
            return "Początkujący";
        }

        private async Task<int> CountFirstDayPurchasesAsync(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
            {
                return 0;
            }

            var escrows = await _escrows.Find(e => e.BorrowerId == userId).ToListAsync();
            if (escrows.Count == 0)
            {
                return 0;
            }

            var offerIds = escrows.Select(e => e.OfferId).Distinct().ToList();
            var offers = await _offers.Find(o => offerIds.Contains(o.OfferId)).ToListAsync();
            var offersById = offers.ToDictionary(o => o.OfferId, o => o);

            var count = 0;
            foreach (var escrow in escrows)
            {
                if (!offersById.TryGetValue(escrow.OfferId, out var offer))
                {
                    continue;
                }

                var firstDayLimit = offer.CreatedAt.AddDays(1);
                if (escrow.CreatedAt >= offer.CreatedAt && escrow.CreatedAt <= firstDayLimit)
                {
                    count++;
                }
            }

            return count;
        }

        private static bool IsReport(Offer offer)
        {
            if (offer == null)
            {
                return false;
            }

            if (string.Equals(offer.OfferKind, "WantToTake", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            var category = offer.Category ?? string.Empty;
            if (string.IsNullOrWhiteSpace(category))
            {
                return false;
            }

            var type = category;
            var separatorIndex = category.IndexOf('|');
            if (separatorIndex >= 0)
            {
                type = category.Substring(0, separatorIndex);
            }

            return string.Equals(type.Trim(), "Zgłoszenie", StringComparison.OrdinalIgnoreCase);
        }
    }
}