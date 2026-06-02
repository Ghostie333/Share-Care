using Microsoft.Extensions.Hosting;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using Share_Care.models;

namespace Share_Care.Services
{
    public class ExpiredOffersCleanupService(
        ILogger<ExpiredOffersCleanupService> logger,
        IMongoDatabase db,
        GridFSBucket gridFs) : BackgroundService
    {
        private readonly ILogger<ExpiredOffersCleanupService> _logger = logger;
        private readonly IMongoCollection<Offer> _offers = db.GetCollection<Offer>("offers");
        private readonly GridFSBucket _gridFs = gridFs;

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Uruchamiaj okresowe czyszczenie wygasłych ofert co 15 minut.
            using var timer = new PeriodicTimer(TimeSpan.FromMinutes(15));

            // Pierwsze przebiegnięcie od razu po starcie aplikacji.
            await CleanupExpiredOffersAsync(stoppingToken);

            while (!stoppingToken.IsCancellationRequested &&
                   await timer.WaitForNextTickAsync(stoppingToken))
            {
                await CleanupExpiredOffersAsync(stoppingToken);
            }
        }

        private async Task CleanupExpiredOffersAsync(CancellationToken cancellationToken)
        {
            try
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

                var expiredOffers = await _offers.Find(expiredFilter).ToListAsync(cancellationToken);
                if (expiredOffers.Count == 0)
                {
                    return;
                }

                var offerIds = expiredOffers
                    .Select(o => o.OfferId)
                    .Where(id => !string.IsNullOrWhiteSpace(id))
                    .ToList();

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
                            await _gridFs.DeleteAsync(oid, cancellationToken);
                        }
                        catch (GridFSFileNotFoundException)
                        {
                            // Plik został już usunięty - pomijamy.
                        }
                    }
                }

                var deleteResult = await _offers.DeleteManyAsync(
                    o => offerIds.Contains(o.OfferId),
                    cancellationToken);

                _logger.LogInformation(
                    "Usunięto {Count} wygasłych ofert (zgłoszenia/jedzenie).",
                    deleteResult.DeletedCount);
            }
            catch (OperationCanceledException)
            {
                // Zamknięcie aplikacji.
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Błąd podczas czyszczenia wygasłych ofert.");
            }
        }
    }
}
