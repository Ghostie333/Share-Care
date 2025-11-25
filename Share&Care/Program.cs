using System.Linq;
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

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
            "http://localhost:3000",
            "https://localhost:3000",
            "http://192.168.1.68:32769",
            "http://192.168.1.68:7070",
            "https://46.205.192.175:7070",
            "http://46.205.192.175:7070"
        )
        .AllowAnyHeader()
        .AllowAnyMethod();
    });
});
var app = builder.Build();
//builder.Services.AddCors(options =>
//{
//    options.AddPolicy("AllowAll",
//        builder => builder.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
//});

//var app = builder.Build();
//app.UseCors("AllowAll");



if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// WA¯NE: UseRouting przed UseCors
app.UseRouting();

app.UseCors();

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