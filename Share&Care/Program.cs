using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using Share_Care.Hubs;
using Share_Care.Services;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSignalR();
builder.Services.AddHttpClient();

// Pobieranie dozwolonych adresów ze zmiennych środowiskowych
var rawCorsOrigins = Environment.GetEnvironmentVariable("Cors__AllowedOrigins")
    ?? Environment.GetEnvironmentVariable("FRONTEND_ORIGINS");

var corsOriginsList = (rawCorsOrigins ?? string.Empty)
    .Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
    .ToList();

// ZABEZPIECZENIE: Jeśli produkcja i lista jest pusta, dodaj domyślny adres Cloudflare Pages,
// żeby aplikacja od razu ruszyła. Zmień "twoja-nazwa-projektu" na swoją nazwę z Pages.
if (corsOriginsList.Count == 0 && !builder.Environment.IsDevelopment())
{
    corsOriginsList.Add("https://twoja-nazwa-projektu.pages.dev");
}

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        if (corsOriginsList.Count == 0)
        {
            if (builder.Environment.IsDevelopment())
            {
                // Dla localhost w dev mode bez ustawionych zmiennych
                policy.AllowAnyOrigin()
                      .AllowAnyHeader()
                      .AllowAnyMethod();
                // Usunięto AllowCredentials(), bo gryzie się z AllowAnyOrigin()
            }
            return;
        }

        // Dla zdefiniowanych adresów (w tym Cloudflare Pages)
        policy.WithOrigins(corsOriginsList.ToArray())
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials(); // SignalR tego wymaga, więc origins muszą być jawne
    });
});

// MongoDB
var rawConn = Environment.GetEnvironmentVariable("MongoDb__ConnectionString");
var mongoUrl = new MongoUrl(rawConn);
var dbName = mongoUrl.DatabaseName;
Console.WriteLine($"[STARTUP] Using MongoDB URL: {rawConn}");
Console.WriteLine($"[STARTUP] Resolved Database: {dbName}");
var mongoClient = new MongoClient(mongoUrl);
var mongoDatabase = mongoClient.GetDatabase(dbName);
builder.Services.AddSingleton(mongoDatabase);
builder.Services.AddSingleton(new GridFSBucket(mongoDatabase));

// Serwisy
builder.Services.AddSingleton<SecurityService>();
builder.Services.AddScoped<ILoginService, LoginService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IWalletService, WalletService>();
builder.Services.AddScoped<IEscrowService, EscrowService>();
builder.Services.AddScoped<ITransactionService, TransactionService>();
builder.Services.AddScoped<IRewardsService, RewardsService>();
builder.Services.AddHostedService<ExpiredOffersCleanupService>();

builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddHttpClient<IPaymentService, PaymentService>()
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
    {
        AllowAutoRedirect = false
    });

// AUTH: JWT dla Flutter (Web + Mobile)
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        var key = Environment.GetEnvironmentVariable("Auth__Jwt__Key");
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key ?? "")),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();

// CORS musi być dokładnie tutaj - po UseRouting, przed Https/Auth
app.UseCors("Frontend");

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.UseStaticFiles();

app.MapControllers();
app.MapHub<ChatHub>("/chubs/chat");

app.MapGet("/userprofilepage", async context =>
{
    var path = Path.Combine(app.Environment.WebRootPath, "pages", "UserProfilePage", "index.html");
    context.Response.ContentType = "text/html";
    await context.Response.SendFileAsync(path);
});

app.Run();