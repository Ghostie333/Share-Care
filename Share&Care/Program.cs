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

// W kontenerze wystawiamy tylko HTTP (brak nasłuchu HTTPS),
// więc w środowisku deweloperskim NIE wymuszamy przekierowania na HTTPS,
// bo skutkuje to błędem "Connection refused" po przekierowaniu na https://127.0.0.1:7070.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseAuthentication();
app.UseAuthorization();

app.UseDefaultFiles();
app.UseStaticFiles();

// Najpierw mapujemy API i SignalR, aby ścieżki /chat/* nie były
// przechwytywane przez fallback SPA (index.html).
app.MapControllers();
app.MapHub<ChatHub>("/chubs/chat");

// Serwuj Flutter Web spod / (root)
var flutterAppRoot = Path.Combine(app.Environment.WebRootPath, "frontend", "build", "web");
if (Directory.Exists(flutterAppRoot))
{
    var flutterProvider = new PhysicalFileProvider(flutterAppRoot);

    app.UseFileServer(new FileServerOptions
    {
        FileProvider = flutterProvider,
        RequestPath = PathString.Empty, // root
        EnableDefaultFiles = true
    });

    // Fallback dla SPA: tylko jeśli nie trafiono w żaden endpoint ani plik statyczny
    // ani w żaden endpoint API.
    app.MapFallbackToFile("index.html", new StaticFileOptions
    {
        FileProvider = flutterProvider
    });
}

app.MapGet("/userprofilepage", async context =>
{
    var path = Path.Combine(app.Environment.WebRootPath, "pages", "UserProfilePage", "index.html");
    context.Response.ContentType = "text/html";
    await context.Response.SendFileAsync(path);
});

app.Run();