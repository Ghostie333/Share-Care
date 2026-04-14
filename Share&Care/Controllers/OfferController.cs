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

                if (form.Lat.HasValue ^ form.Lng.HasValue)
                {
                    return BadRequest(new { message = "Podaj oba pola: Lat i Lng." });
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
                    ContactNumber = form.ContactNumber ?? string.Empty,
                    Description = form.Description ?? string.Empty,
                    Deposit = form.Deposit,
                    LocationText = string.IsNullOrWhiteSpace(form.LocationText)
                        ? null
                        : form.LocationText!.Trim(),
                    CreatedAt = DateTime.UtcNow,
                    Location = (form.Lat.HasValue && form.Lng.HasValue)
                        ? new GeoJsonPoint<GeoJson2DGeographicCoordinates>(
                            new GeoJson2DGeographicCoordinates(form.Lng.Value, form.Lat.Value))
                        : null,
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
        public async Task<IActionResult> GetAll([FromQuery] OfferFiltersRequest filters, [FromQuery] int page = 1, [FromQuery] int limit = 20)
        {
            try
            {
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

                // Wyszukiwanie tekstowe
                if (!string.IsNullOrWhiteSpace(filters.SearchText))
                {
                    var textFilter = filterBuilder.Or(
                        filterBuilder.Regex(x => x.Title, new BsonRegularExpression(filters.SearchText, "i")),
                        filterBuilder.Regex(x => x.Description, new BsonRegularExpression(filters.SearchText, "i"))
                    );
                    filterList.Add(textFilter);
                }

                // Filtr lokalizacji
                if (filters.Lat.HasValue && filters.Lng.HasValue && filters.RadiusKm.HasValue)
                {
                    var point = GeoJson.Point(GeoJson.Position(filters.Lng.Value, filters.Lat.Value));
                    var locationFilter = filterBuilder.Near(
                        x => x.Location,
                        point,
                        maxDistance: filters.RadiusKm.Value * 1000,
                        minDistance: 0
                    );
                    filterList.Add(locationFilter);
                }

                // Filtr dat
                if (filters.CreatedAfter.HasValue)
                {
                    filterList.Add(filterBuilder.Gte(x => x.CreatedAt, filters.CreatedAfter.Value));
                }
                if (filters.CreatedBefore.HasValue)
                {
                    filterList.Add(filterBuilder.Lte(x => x.CreatedAt, filters.CreatedBefore.Value));
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
        public async Task<IActionResult> GetUserOffers(string userId)
        {
            // Chcemy pobrać wszystkie oferty użytkownika (aktywne i nieaktywne),
            // dlatego nadpisujemy Status na null.
            return await GetAll(new OfferFiltersRequest { UserId = userId, Status = null });
        }

        [HttpGet("get-offer/{offerId}")]
        public async Task<IActionResult> GetOffer(string offerId)
        {
            try
            {
                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
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

        [HttpGet("get-offer-page")]
        public async Task<IActionResult> GetOfferPage(string offerId)
        {
            try
            {
                var offer = await _collection.Find(x => x.OfferId == offerId).FirstOrDefaultAsync();
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
        public async Task<IActionResult> UpdateOffer([FromBody] CreateOfferRequest form, string offerId)
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

                var update = Builders<Offer>.Update.Set(x => x.Title, form.Title)
                    .Set(x => x.ContactName, form.ContactName)
                    .Set(x => x.Category, form.Category)
                    .Set(x => x.ContactNumber, form.ContactNumber)
                    .Set(x => x.Description, form.Description);

                await _collection.FindOneAndUpdateAsync(x => x.OfferId == offerId, update);

                return Ok("Pomyślnie zaktualizowano profil użytkownika");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się zaktualizować informacji o użytkowniku");
                return StatusCode(500);
            }
        }
    }
}