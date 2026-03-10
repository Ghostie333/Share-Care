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

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("offer")]
    public class OfferController : Controller
    {
        private readonly ILogger<OfferController> _logger;
        private readonly IMongoCollection<Offer> _collection;
        private readonly GridFSBucket _gridFS;

        public OfferController(ILogger<OfferController> logger, IMongoDatabase db)
        {
            _logger = logger;
            _collection = db.GetCollection<Offer>("offers");
            _gridFS = new GridFSBucket(db);
        }

        public sealed class CreateOfferForm
        {
            [Required]
            public string? Title { get; set; }

            [Required]
            public string? ContactName { get; set; }

            [Required]
            public string? Category { get; set; }

            public string ContactNumber { get; set; } = string.Empty;
            public string Description { get; set; } = string.Empty;

            [Range(-90, 90, ErrorMessage = "Lat musi być w zakresie [-90, 90].")]
            public double? Lat { get; set; }

            [Range(-180, 180, ErrorMessage = "Lng musi być w zakresie [-180, 180].")]
            public double? Lng { get; set; }

            public List<IFormFile>? Images { get; set; }
        }

        // POST /offer/create-offer
        [Authorize]
        [HttpPost("create-offer")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> CreateOffer([FromForm] CreateOfferForm form)
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

        [HttpGet("get-offers")]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var offers = await _collection.Find(_ => true).ToListAsync();
                return Ok(offers);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania ofert z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
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

        [HttpGet("get-user-offers/{userId}")]
        public async Task<IActionResult> GetUserOffers(string userId)
        {
            try
            {
                var offers = await _collection.Find(x => x.UserId == userId).ToListAsync();
                return Ok(offers);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania ofert użytkownika z MongoDB");
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
                if (offer.ImageIds is { Count: > 0 })
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
    }
}