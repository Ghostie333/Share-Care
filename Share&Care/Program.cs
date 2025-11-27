using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;

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


// AUTH: automatyczny wybór Cookies/JWT (PolicyScheme)
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
        o.ExpireTimeSpan = TimeSpan.FromDays(7); // Gdy u¿ytkownik pozostaje aktywny, odœwie¿amy wa¿noœæ o 7 dni
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
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    }
);

/*
//CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
            "http://localhost:3000",
            "https://localhost:3000"
        )
        .AllowAnyHeader()
        .AllowAnyMethod();
    });
});
*/
var app = builder.Build();


if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();
//app.UseCors();
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapControllers();

app.MapGet("/userprofilepage", async context =>
{
    var path = Path.Combine(app.Environment.WebRootPath, "pages", "UserProfilePage", "index.html");
    context.Response.ContentType = "text/html";
    await context.Response.SendFileAsync(path);
});

app.Run();