using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using MongoDB.Driver.GeoJsonObjectModel;
using MongoDB.Driver.GridFS;
using Share_Care.models;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("offer")]
    public class OfferController : Controller
    {
        private readonly ILogger<MainPageController> _logger;
        private readonly IMongoCollection<Offer> _collection;
        public OfferController(ILogger<MainPageController> logger, IMongoDatabase db)
        {
            _logger = logger;
            _collection = db.GetCollection<Offer>("offers");
        }
        public sealed class CreateOfferForm
        {
            [Required]
            public string? UserId { get; set; }
            [Required]
            public string? Title { get; set; }
            [Required]
            public string? ContactName { get; set; }
            [Required]
            public string? Category { get; set; }
            public string ContactNumber { get; set; } = string.Empty;
            public string Description { get; set; } = string.Empty;

            // Google Maps i większość klientów używa { lat, lng }
            [Range(-90, 90, ErrorMessage = "Lat musi być w zakresie [-90, 90].")]
            public double? Lat { get; set; }

            [Range(-180, 180, ErrorMessage = "Lng musi być w zakresie [-180, 180].")]
            public double? Lng { get; set; }

            // Wiele plików: nazwa pola po stronie klienta: images
            public List<IFormFile>? Images { get; set; }
        }

        // GET /offer/all
        [HttpGet("all")]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var offers = await _collection.Find(_ => true).ToListAsync();
                return Ok(offers);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd pobierania danych z MongoDB");
                return Problem("Błąd bazy danych", statusCode: StatusCodes.Status500InternalServerError);
            }
        }

        // POST /offer/create-offer (multipart/form-data: pola + images[])
        [HttpPost("create-offer")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(50_000_000)]
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<IActionResult> CreateOffer([FromBody] CreateOfferForm form)
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


                // Upload obrazów do GridFS
                var imageIds = new List<string>();
                if (form.Images != null && form.Images.Count > 0)
                {
                    var bucket = new GridFSBucket(_collection.Database);

                    foreach (var file in form.Images)
                    {
                        if (file == null || file.Length == 0) continue;

                        using var stream = file.OpenReadStream();
                        var fileId = await bucket.UploadFromStreamAsync(
                            file.FileName,
                            stream,
                            new GridFSUploadOptions
                            {
                                Metadata = new BsonDocument
                                {
                                    { "contentType", file.ContentType ?? "application/octet-stream" },
                                    { "originalName", file.FileName },
                                    { "userId", form.UserId ?? string.Empty }
                                }
                            });

                        imageIds.Add(fileId.ToString());
                    }
                }

                var offer = new Offer
                {
                    UserId = form.UserId!,
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
    }
}
