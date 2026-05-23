using LocalApi.Data;
using LocalApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LocalApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController(AppDbContext dbContext) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Product>>> GetAll(CancellationToken cancellationToken)
    {
        var products = await dbContext.Products
            .AsNoTracking()
            .OrderBy(p => p.Id)
            .ToListAsync(cancellationToken);

        return Ok(products);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Product>> GetById(int id, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

        if (product is null)
        {
            return NotFound();
        }

        return Ok(product);
    }
}
