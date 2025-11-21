using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class WeatherForecastController : ControllerBase
    {
        private static readonly string[] Summaries = new[]
        {
            "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
        };

        private readonly ILogger<WeatherForecastController> _logger;
        private readonly IMongoCollection<WeatherForecast> _collection;

        public WeatherForecastController(ILogger<WeatherForecastController> logger, IMongoDatabase db)
        {
            _logger = logger;
            _collection = db.GetCollection<WeatherForecast>("weatherforecasts");
        }

        [HttpGet(Name = "GetWeatherForecast")]
        public async Task<IEnumerable<WeatherForecast>> Get()
        {
            // Generowanie prognoz
            var forecasts = Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateTime.Now.AddDays(index), // zamiast DateOnly.FromDateTime(...),
                TemperatureC = Random.Shared.Next(-20, 55),
                Summary = WeatherForecastController.Summaries[Random.Shared.Next(WeatherForecastController.Summaries.Length)]
            }).ToList();

            // Zapis do Mongo
            await _collection.InsertManyAsync(forecasts);

            return forecasts;
        }

        [HttpGet("all")]
        public async Task<IEnumerable<WeatherForecast>> GetAll()
        {
            try
            {
                var forecasts = await _collection.Find(_ => true).ToListAsync();
                return forecasts;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "B³¹d pobierania danych z MongoDB");
                throw;
            }
        }
    }
}
