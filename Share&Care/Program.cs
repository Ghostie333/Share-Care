using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// MongoDB
var mongoConnectionString = builder.Configuration.GetConnectionString("MongoDB");
var mongoClient = new MongoClient(mongoConnectionString);
var mongoDatabase = mongoClient.GetDatabase("testdb");
builder.Services.AddSingleton(mongoDatabase);

var app = builder.Build();

// Middleware
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();

// **to pozwala na serwowanie plików statycznych z wwwroot**
app.UseDefaultFiles();   // pozwala automatycznie wczytaæ index.html
app.UseStaticFiles();

app.MapControllers();

app.Run();
