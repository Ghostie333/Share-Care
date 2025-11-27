using System.Linq;
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


// CORS
//builder.Services.AddCors(options =>
//{
//    options.AddDefaultPolicy(policy =>
//    {
//        policy.WithOrigins(
//            "http://localhost:3000",
//            "https://localhost:3000"
//        )
//        .AllowAnyHeader()
//        .AllowAnyMethod();
//    });
//});
var app = builder.Build();


if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();
//app.UseCors();
app.UseHttpsRedirection();
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