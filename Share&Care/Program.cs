using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.Services;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// MongoDB
var rawConn = Environment.GetEnvironmentVariable("MongoDb__ConnectionString");

var mongoUrl = new MongoUrl(rawConn);
var dbName = mongoUrl.DatabaseName;
Console.WriteLine($"[STARTUP] Using MongoDB URL: {rawConn}");
Console.WriteLine($"[STARTUP] Resolved Database: {dbName}");

var mongoClient = new MongoClient(mongoUrl);
var mongoDatabase = mongoClient.GetDatabase(dbName);
builder.Services.AddSingleton(mongoDatabase);


// SecurityService i LoginService
builder.Services.AddSingleton<SecurityService>();
builder.Services.AddScoped<LoginService>();

// AUTH: automatyczny wyb�r Cookies/JWT (PolicyScheme)
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Smart";
    options.DefaultChallengeScheme = "Smart";
})
    .AddPolicyScheme("Smart", "JWT or Cookies", o =>
    {
        o.ForwardDefaultSelector = ctx =>
        {
            var hasBearer = ctx.Request.Headers["Authorization"]
                .FirstOrDefault()?.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) == true;
            return hasBearer ? JwtBearerDefaults.AuthenticationScheme : CookieAuthenticationDefaults.AuthenticationScheme;
        };
    })
    .AddCookie(o =>
    {
        o.Cookie.Name = ".sharecare.auth";
        o.Cookie.HttpOnly = true;
        // Dla cross-site w produkcji: None + Secure (wymaga HTTPS)
        // o.Cookie.SameSite = SameSiteMode.None;
        // o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        o.SlidingExpiration = true;
        o.ExpireTimeSpan = TimeSpan.FromDays(7); // Gdy u�ytkownik pozostaje aktywny, od�wie�amy wa�no�� o 7 dni
        o.Events.OnRedirectToLogin = ctx => { ctx.Response.StatusCode = StatusCodes.Status401Unauthorized; return Task.CompletedTask; };
        o.Events.OnRedirectToAccessDenied = ctx => { ctx.Response.StatusCode = StatusCodes.Status403Forbidden; return Task.CompletedTask; };
    })
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
    }
);

var app = builder.Build();


if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.UseDefaultFiles();
app.UseStaticFiles();

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
    app.MapFallbackToFile("index.html", new StaticFileOptions
    {
        FileProvider = flutterProvider
    });
}

app.MapControllers();

app.MapGet("/userprofilepage", async context =>
{
    var path = Path.Combine(app.Environment.WebRootPath, "pages", "UserProfilePage", "index.html");
    context.Response.ContentType = "text/html";
    await context.Response.SendFileAsync(path);
});

app.Run();