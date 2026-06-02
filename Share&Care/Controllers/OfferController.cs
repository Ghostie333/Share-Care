using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using MongoDB.Driver.GeoJsonObjectModel;
using MongoDB.Driver.GridFS;
using Share_Care.models;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Share_Care.Models.Requests;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("offer")]
    public class OfferController(ILogger<OfferController> logger, IMongoDatabase db, GridFSBucket? gridFs = null) : ControllerBase
    {
        private readonly ILogger<OfferController> _logger = logger;
        private readonly IMongoCollection<Offer> _collection = db.GetCollection<Offer>("offers");
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly GridFSBucket? _gridFS = gridFs;

        // POST /offer/create-offer
        [Authorize]
        [HttpPost("create-offer")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> CreateOffer([FromForm] CreateOfferRequest form)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return ValidationProblem(ModelState);
                }

                if (string.Equals(form.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase) &&
                    (!form.Deposit.HasValue || form.Deposit.Value <= 0))
                {
                    return BadRequest(new { message = "Kaucja jest wymagana dla wypożyczenia." });
                }

                if (IsFoodCategory(form.Category) &&
                    !string.Equals(form.OfferKind, "Give", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { message = "Dla kategorii Jedzenie dostępna jest tylko opcja Oddanie." });
                }

                if (string.Equals(form.OfferKind, "WantToTake", StringComparison.OrdinalIgnoreCase))
                {
                    if (!form.ExpirationDate.HasValue)
                    {
                        return BadRequest(new { message = "Termin ważności jest wymagany dla zgłoszenia." });
                    }
                }

                if (!string.IsNullOrWhiteSpace(form.Category) &&
                    form.Category.Contains("Jedzenie", StringComparison.OrdinalIgnoreCase) &&
                    !form.ExpirationDate.HasValue)
                {
                    return BadRequest(new { message = "Termin ważności jest wymagany dla kategorii Jedzenie." });
                }

                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                // Upload obrazów do GridFS
                var imageIds = new List<string>();
                if (form.Images != null && form.Images.Count > 0)
                {
                    if (_gridFS is null)
                    {
                        return Problem("Brak konfiguracji GridFS", statusCode: StatusCodes.Status500InternalServerError);
                    }

                    foreach (var file in form.Images)
                    {
                        if (file == null || file.Length == 0) continue;

                        using var stream = file.OpenReadStream();
                        var fileId = await _gridFS.UploadFromStreamAsync(
                            file.FileName,
                            stream,
                            new GridFSUploadOptions
                            {
                                Metadata = new BsonDocument
                                {
                                    { "contentType", file.ContentType ?? "application/octet-stream" },
                                    { "originalName", file.FileName },
                                    { "userId", currentUserId }
                                }
                            });

                        imageIds.Add(fileId.ToString());
                    }
                }

                var offer = new Offer
                {
                    UserId = currentUserId,
                    Title = form.Title!,
                    ContactName = form.ContactName!,
                    Category = form.Category!,
                    OfferKind = string.IsNullOrWhiteSpace(form.OfferKind) ? "Borrow" : form.OfferKind!,
                    ContactNumber = form.ContactNumber ?? string.Empty,
                    Description = form.Description ?? string.Empty,
                    Deposit = form.Deposit,
                    ExpirationDate = form.ExpirationDate,
                    LocationText = string.IsNullOrWhiteSpace(form.LocationText)
                        ? null
                        : form.LocationText!.Trim(),
                    CreatedAt = DateTime.UtcNow,
                    ImageIds = imageIds
                };

                await _collection.InsertOneAsync(offer);
                return Ok(new { message = "Oferta utworzona pomyślnie", offerId = offer.OfferId, imageIds });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd tworzenia oferty w MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        // GET /offer/get-offers?userId=123&category=Elektronika&status=Active&page=1&limit=20
        [HttpGet("get-offers")]
        public async Task<IActionResult> GetAll([FromQuery] OfferFiltersRequest filters, [FromQuery] int page = 1, [FromQuery] int limit = 20, [FromQuery] bool includeChatOnly = false)
        {
            try
            {
                await DeleteExpiredReportAndFoodOffersAsync();

                page = Math.Max(page, 1);
                limit = Math.Clamp(limit, 1, 100); // zabezpieczenie, żeby nie zabić bazy

                var filterBuilder = Builders<Offer>.Filter;
                var filterList = new List<FilterDefinition<Offer>>();

                // Filtr użytkownika
                if (!string.IsNullOrWhiteSpace(filters.UserId))
                {
                    filterList.Add(filterBuilder.Eq(x => x.UserId, filters.UserId));
                }

                // Filtr kategorii
                if (!string.IsNullOrWhiteSpace(filters.Category))
                {
                    filterList.Add(filterBuilder.Eq(x => x.Category, filters.Category));
                }

                // Filtr statusu
                if (!string.IsNullOrWhiteSpace(filters.Status))
                {
                    filterList.Add(filterBuilder.Eq(x => x.Status, filters.Status));
                }

                if (!includeChatOnly)
                {
                    filterList.Add(filterBuilder.Ne(x => x.IsChatOnly, true));
                }

                // Wyszukiwanie tekstowe
                if (!string.IsNullOrWhiteSpace(filters.SearchText))
                {
                    var textFilter = filterBuilder.Or(
                        filterBuilder.Regex(x => x.Title, new BsonRegularExpression(filters.SearchText, "i")),
                        filterBuilder.Regex(x => x.Description, new BsonRegularExpression(filters.SearchText, "i"))
                    );
                    filterList.Add(textFilter);
                }

                var finalFilter = filterList.Count > 0
                    ? filterBuilder.And(filterList)
                    : filterBuilder.Empty;

                var skip = (page - 1) * limit;

                var options = new FindOptions<Offer, Offer>
                {
                    Sort = Builders<Offer>.Sort.Descending(o => o.CreatedAt),
                    Skip = skip,
                    Limit = limit
                };

                var cursor = await _collection.FindAsync(finalFilter, options);
                var offers = await cursor.ToListAsync();

                return Ok(new
                {
                    page,
                    limit,
                    returned = offers.Count,
                    items = offers
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania ofert z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        // Alias
        [HttpGet("get-user-offers/{userId}")]
        public async Task<IActionResult> GetUserOffers(string userId, [FromQuery] bool includeChatOnly = false)
        {
            // Chcemy pobrać wszystkie oferty użytkownika (aktywne i nieaktywne),
            // dlatego nadpisujemy Status na null.
            return await GetAll(new OfferFiltersRequest { UserId = userId, Status = null }, includeChatOnly: includeChatOnly);
        }

        [Authorize]
        [HttpPost("create-chat-offer")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> CreateChatOffer([FromForm] CreateChatOfferRequest form)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return ValidationProblem(ModelState);
                }

                if (string.Equals(form.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase) &&
                    (!form.Deposit.HasValue || form.Deposit.Value <= 0))
                {
                    return BadRequest(new { message = "Kaucja jest wymagana dla wypozyczenia." });
                }

                if (IsFoodCategory(form.Category) &&
                    !string.Equals(form.OfferKind, "Give", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { message = "Dla kategorii Jedzenie dostępna jest tylko opcja Oddanie." });
                }

                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var report = await _collection.Find(x => x.OfferId == form.ReportId).FirstOrDefaultAsync();
                if (report is null)
                {
                    return NotFound("Zgloszenie nie istnieje.");
                }

                if (!IsReportListing(report))
                {
                    return BadRequest("Wskazana oferta nie jest zgloszeniem.");
                }

                var imageIds = new List<string>();
                if (form.Images != null && form.Images.Count > 0)
                {
                    if (_gridFS is null)
                    {
                        return Problem("Brak konfiguracji GridFS", statusCode: StatusCodes.Status500InternalServerError);
                    }

                    foreach (var file in form.Images)
                    {
                        if (file == null || file.Length == 0) continue;

                        using var stream = file.OpenReadStream();
                        var fileId = await _gridFS.UploadFromStreamAsync(
                            file.FileName,
                            stream,
                            new GridFSUploadOptions
                            {
                                Metadata = new BsonDocument
                                {
                                    { "contentType", file.ContentType ?? "application/octet-stream" },
                                    { "originalName", file.FileName },
                                    { "userId", currentUserId }
                                }
                            });

                        imageIds.Add(fileId.ToString());
                    }
                }

                var offer = new Offer
                {
                    UserId = currentUserId,
                    Title = form.Title!,
                    ContactName = form.ContactName!,
                    Category = form.Category!,
                    OfferKind = string.IsNullOrWhiteSpace(form.OfferKind) ? "Borrow" : form.OfferKind!,
                    ContactNumber = form.ContactNumber ?? string.Empty,
                    Description = form.Description ?? string.Empty,
                    Deposit = form.Deposit,
                    ExpirationDate = form.ExpirationDate,
                    LocationText = string.IsNullOrWhiteSpace(form.LocationText)
                        ? null
                        : form.LocationText!.Trim(),
                    CreatedAt = DateTime.UtcNow,
                    ImageIds = imageIds,
                    IsChatOnly = true,
                    RelatedReportId = form.ReportId
                };

                await _collection.InsertOneAsync(offer);

                return Ok(new { message = "Oferta czatowa utworzona", offerId = offer.OfferId, imageIds });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Blad tworzenia oferty czatowej");
                return Problem("Blad bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        private static bool IsReportListing(Offer offer)
        {
            if (string.Equals(offer.OfferKind, "WantToTake", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            var raw = (offer.Category ?? string.Empty).Trim();
            if (raw.Contains('|'))
            {
                var parts = raw.Split('|');
                raw = parts.Length > 0 ? parts[0].Trim() : raw;
            }

            return string.Equals(raw, "Zgloszenie", StringComparison.OrdinalIgnoreCase);
        }

        [HttpGet("get-offer/{offerId}")]
        public async Task<IActionResult> GetOffer(string offerId)
        {
            try
            {
                await DeleteExpiredReportAndFoodOffersAsync();

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                return Ok(offer);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Bład pobierania oferty z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }


        // DELETE /offer/remove-offer/{offerId}
        [Authorize]
        [HttpDelete("remove-offer/{offerId}")]
        public async Task<IActionResult> RemoveOffer(string offerId)
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                if (!string.Equals(offer.UserId, currentUserId, StringComparison.Ordinal))
                {
                    return Forbid(); // wywołujący nie jest właścicielem
                }

                await _collection.DeleteOneAsync(x => x.OfferId == offerId);

                // Best-effort: usuń pliki z GridFS powiązane z ofertą
                if (_gridFS is not null && offer.ImageIds is { Count: > 0 })
                {
                    foreach (var id in offer.ImageIds)
                    {
                        if (!ObjectId.TryParse(id, out var oid)) continue;

                        try
                        {
                            await _gridFS.DeleteAsync(oid);
                        }
                        catch (GridFSFileNotFoundException)
                        {
                            // plik już nie istnieje - ignoruj
                        }
                    }
                }

                return Ok(new { message = "Usunięto ofertę" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd usunięcia oferty z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }


        // Oferta zmienia status na "Closed"
        [Authorize]
        [HttpPost("close-offer/{offerId}")]
        public async Task<IActionResult> CloseOffer(string offerId)
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                if (!string.Equals(offer.UserId, currentUserId, StringComparison.Ordinal))
                {
                    return Forbid(); // wywołujący nie jest właścicielem
                }

                var update = Builders<Offer>.Update.Set(x => x.Status, "Inactive");
                await _collection.FindOneAndUpdateAsync(x => x.OfferId == offerId, update);


                return Ok(new { message = "Zamknięto ofertę" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd zamknięcia oferty");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        [Authorize]
        [HttpPost("activate-offer/{offerId}")]
        public async Task<IActionResult> ActivateOffer(string offerId)
        {
            try
            {
                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                if (!string.Equals(offer.UserId, currentUserId, StringComparison.Ordinal))
                {
                    return Forbid();
                }

                var update = Builders<Offer>.Update.Set(x => x.Status, "Active");
                await _collection.FindOneAndUpdateAsync(x => x.OfferId == offerId, update);

                return Ok(new { message = "Aktywowano ofertę" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd aktywacji oferty");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        [HttpGet("get-offer-page")]
        public async Task<IActionResult> GetOfferPage(string offerId)
        {
            try
            {
                await DeleteExpiredReportAndFoodOffersAsync();

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                return Ok(offer);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Bład pobierania oferty z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        [HttpGet("image/{imageId}")]
        [ResponseCache(Duration = 86400)]
        public async Task<IActionResult> GetImage(string imageId)
        {
            try
            {
                if (_gridFS is null)
                {
                    return Problem("Brak konfiguracji GridFS", statusCode: StatusCodes.Status500InternalServerError);
                }

                if (!ObjectId.TryParse(imageId, out var objectId))
                {
                    return BadRequest("Nieprawidłowy format ID obrazu");
                }

                var filter = Builders<GridFSFileInfo>.Filter.Eq("_id", objectId);
                var fileInfo = await _gridFS.Find(filter).FirstOrDefaultAsync();

                if (fileInfo == null)
                {
                    return NotFound();
                }

                var contentType = fileInfo.Metadata?.GetValue("contentType", "image/jpeg").AsString
                                  ?? "image/jpeg";

                var stream = await _gridFS.OpenDownloadStreamAsync(objectId);
                return File(stream, contentType);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania obrazu z bazy danych");
                return Problem("Błąd pobierania obrazu", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        // Aktualizacja oferty
        [Authorize]
        [HttpPut("update-offer/{offerId}")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> UpdateOffer([FromForm] CreateOfferRequest form, string offerId)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return ValidationProblem(ModelState);
                }

                var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(currentUserId))
                {
                    return Unauthorized();
                }

                // Walidacje specyficzne dla aktualizacji
                if (string.Equals(form.OfferKind, "Borrow", StringComparison.OrdinalIgnoreCase) &&
                    (!form.Deposit.HasValue || form.Deposit.Value <= 0))
                {
                    return BadRequest(new { message = "Kaucja jest wymagana dla wypożyczenia." });
                }

                if (IsFoodCategory(form.Category) &&
                    !string.Equals(form.OfferKind, "Give", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { message = "Dla kategorii Jedzenie dostępna jest tylko opcja Oddanie." });
                }

                if (string.Equals(form.OfferKind, "WantToTake", StringComparison.OrdinalIgnoreCase))
                {
                    if (string.IsNullOrWhiteSpace(form.ContactNumber))
                    {
                        return BadRequest(new { message = "Numer telefonu jest wymagany dla zgłoszenia." });
                    }

                    if (string.IsNullOrWhiteSpace(form.LocationText))
                    {
                        return BadRequest(new { message = "Lokalizacja jest wymagana dla zgłoszenia." });
                    }

                    if (!form.ExpirationDate.HasValue)
                    {
                        return BadRequest(new { message = "Termin ważności jest wymagany dla zgłoszenia." });
                    }
                }

                if (!string.IsNullOrWhiteSpace(form.Category) &&
                    form.Category.Contains("Jedzenie", StringComparison.OrdinalIgnoreCase) &&
                    !form.ExpirationDate.HasValue)
                {
                    return BadRequest(new { message = "Termin ważności jest wymagany dla kategorii Jedzenie." });
                }

                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                if (offer is null)
                {
                    return NotFound();
                }

                if (!string.Equals(offer.UserId, currentUserId, StringComparison.Ordinal))
                {
                    return Forbid();
                }

                var update = Builders<Offer>.Update.Set(x => x.Title, form.Title)
                    .Set(x => x.ContactName, form.ContactName)
                    .Set(x => x.Category, form.Category)
                    .Set(x => x.OfferKind, string.IsNullOrWhiteSpace(form.OfferKind) ? "Borrow" : form.OfferKind)
                    .Set(x => x.ContactNumber, form.ContactNumber)
                    .Set(x => x.Description, form.Description)
                    .Set(x => x.Deposit, form.Deposit)
                    .Set(x => x.ExpirationDate, form.ExpirationDate)
                    .Set(x => x.LocationText, string.IsNullOrWhiteSpace(form.LocationText) ? null : form.LocationText.Trim());

                var imageIds = offer.ImageIds ?? new List<string>();
                if (form.Images != null && form.Images.Count > 0)
                {
                    if (_gridFS is null)
                    {
                        return Problem("Brak konfiguracji GridFS", statusCode: StatusCodes.Status500InternalServerError);
                    }

                    foreach (var file in form.Images)
                    {
                        if (file == null || file.Length == 0) continue;

                        using var stream = file.OpenReadStream();
                        var fileId = await _gridFS.UploadFromStreamAsync(
                            file.FileName,
                            stream,
                            new GridFSUploadOptions
                            {
                                Metadata = new BsonDocument
                                {
                                    { "contentType", file.ContentType ?? "application/octet-stream" },
                                    { "originalName", file.FileName },
                                    { "userId", currentUserId }
                                }
                            });

                        imageIds.Add(fileId.ToString());
                    }

                    update = update.Set(x => x.ImageIds, imageIds);
                }

                await _collection.FindOneAndUpdateAsync(x => x.OfferId == offerId, update);

                var updated = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
                return Ok(updated ?? offer);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się zaktualizować informacji o użytkowniku");
                return StatusCode(500);
            }
        }

        private async Task DeleteExpiredReportAndFoodOffersAsync()
        {
            var now = DateTime.UtcNow;

            var filterBuilder = Builders<Offer>.Filter;
            var expiredFilter = filterBuilder.And(
                filterBuilder.Lte(o => o.ExpirationDate, now),
                filterBuilder.Or(
                    filterBuilder.Eq(o => o.OfferKind, "WantToTake"),
                    filterBuilder.Regex(o => o.Category, new BsonRegularExpression("jedzenie", "i")),
                    filterBuilder.Regex(o => o.Category, new BsonRegularExpression("^zgloszenie(\\||$)", "i")),
                    filterBuilder.Regex(o => o.Category, new BsonRegularExpression("^zgłoszenie(\\||$)", "i"))
                )
            );

            var expiredOffers = await _collection.Find(expiredFilter).ToListAsync();
            if (expiredOffers.Count == 0)
            {
                return;
            }

            var offerIds = expiredOffers.Select(o => o.OfferId).Where(id => !string.IsNullOrWhiteSpace(id)).ToList();

            if (_gridFS is not null)
            {
                foreach (var offer in expiredOffers)
                {
                    if (offer.ImageIds is not { Count: > 0 })
                    {
                        continue;
                    }

                    foreach (var imageId in offer.ImageIds)
                    {
                        if (!ObjectId.TryParse(imageId, out var oid))
                        {
                            continue;
                        }

                        try
                        {
                            await _gridFS.DeleteAsync(oid);
                        }
                        catch (GridFSFileNotFoundException)
                        {
                            // Plik został już usunięty - pomijamy.
                        }
                    }
                }
            }

            await _collection.DeleteManyAsync(o => offerIds.Contains(o.OfferId));
        }

        private static bool IsFoodCategory(string? category)
        {
            return !string.IsNullOrWhiteSpace(category) &&
                   category.Contains("Jedzenie", StringComparison.OrdinalIgnoreCase);
        }
    }
}