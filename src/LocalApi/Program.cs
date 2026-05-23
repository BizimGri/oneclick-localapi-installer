using LocalApi.Data;
using LocalApi.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

if (OperatingSystem.IsWindows())
{
    builder.Host.UseWindowsService();
}

builder.Services.AddControllers();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
}

builder.Services.AddDbContext<AppDbContext>((serviceProvider, options) =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var provider = configuration["DatabaseProvider"]?.Trim();

    switch (provider?.ToLowerInvariant())
    {
        case "sqlserver":
            options.UseSqlServer(
                configuration.GetConnectionString("SqlServer"),
                sqlServerOptions => sqlServerOptions.EnableRetryOnFailure());
            break;

        case "postgresql":
            options.UseNpgsql(configuration.GetConnectionString("PostgreSql"));
            break;

        case "sqlite":
            options.UseSqlite(configuration.GetConnectionString("Sqlite"));
            break;

        default:
            throw new InvalidOperationException(
                "Invalid or missing DatabaseProvider. Expected one of: SqlServer, PostgreSql, Sqlite.");
    }
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.MapControllers();

if (args.Contains("--migrate", StringComparer.OrdinalIgnoreCase))
{
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    static async Task<bool> SqliteProductsTableExistsAsync(AppDbContext context)
    {
        await using var connection = context.Database.GetDbConnection();
        if (connection.State != System.Data.ConnectionState.Open)
        {
            await connection.OpenAsync();
        }

        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='Products';";
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result) > 0;
    }

    async Task EnsureSchemaAsync(AppDbContext context)
    {
        var isSqlite = string.Equals(context.Database.ProviderName, "Microsoft.EntityFrameworkCore.Sqlite", StringComparison.Ordinal);

        if (context.Database.IsRelational())
        {
            await context.Database.MigrateAsync();
        }
        else
        {
            await context.Database.EnsureCreatedAsync();
        }

        if (isSqlite && !await SqliteProductsTableExistsAsync(context))
        {
            // Self-heal stale sqlite files where migration history exists but schema drifted.
            await context.Database.EnsureDeletedAsync();

            // If there are no discoverable migrations at runtime, EnsureCreated still builds schema from model.
            await context.Database.EnsureCreatedAsync();

            if (!await SqliteProductsTableExistsAsync(context))
            {
                throw new InvalidOperationException("SQLite schema recovery failed: Products table is still missing.");
            }
        }
    }

    async Task EnsureSeedAsync(AppDbContext context)
    {
        if (!await context.Products.AnyAsync())
        {
            context.Products.AddRange(
                new Product { Name = "Kalem", Price = 15m },
                new Product { Name = "Defter", Price = 45m },
                new Product { Name = "Kitap", Price = 120m });

            await context.SaveChangesAsync();
        }
    }

    await EnsureSchemaAsync(dbContext);
    await EnsureSeedAsync(dbContext);

    return;
}

app.Run();
