using LocalApi.Models;
using Microsoft.EntityFrameworkCore;

namespace LocalApi.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Name)
                .IsRequired()
                .HasMaxLength(200);
            entity.Property(p => p.Price)
                .HasColumnType("decimal(18,2)");
        });
    }
}
