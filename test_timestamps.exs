# Test script to verify timestamp handling in repositories

# Start the applications
{:ok, _} = Application.ensure_all_started(:command_service)
{:ok, _} = Application.ensure_all_started(:query_service)

alias CommandService.Infrastructure.Repositories.CategoryRepository, as: CommandCategoryRepo
alias CommandService.Infrastructure.Repositories.ProductRepository, as: CommandProductRepo
alias CommandService.Domain.Entities.{Category, Product}

alias QueryService.Infrastructure.Repositories.CategoryRepository, as: QueryCategoryRepo
alias QueryService.Infrastructure.Repositories.ProductRepository, as: QueryProductRepo

IO.puts("\n=== Testing Command Service Timestamp Handling ===")

# Create a test category
category_id = "test_cat_#{System.unique_integer([:positive])}"
{:ok, category} = Category.new(category_id, "Test Category")
{:ok, saved_category} = CommandCategoryRepo.save(category)

IO.puts("\nSaved Category:")
IO.inspect(saved_category, pretty: true)
IO.puts("Created at: #{saved_category.created_at}")
IO.puts("Updated at: #{saved_category.updated_at}")

# Create a test product
product_id = "test_prod_#{System.unique_integer([:positive])}"
{:ok, product} = Product.new(product_id, "Test Product", "99.99", category_id)
{:ok, saved_product} = CommandProductRepo.save(product)

IO.puts("\nSaved Product:")
IO.inspect(saved_product, pretty: true)
IO.puts("Created at: #{saved_product.created_at}")
IO.puts("Updated at: #{saved_product.updated_at}")

# Small delay to ensure different timestamps
Process.sleep(1000)

# Update the category
{:ok, updated_category} = Category.update_name(saved_category, "Updated Test Category")
{:ok, saved_updated_category} = CommandCategoryRepo.update(updated_category)

IO.puts("\nUpdated Category:")
IO.puts("Created at: #{saved_updated_category.created_at}")
IO.puts("Updated at: #{saved_updated_category.updated_at}")
IO.puts("Timestamps different? #{saved_updated_category.created_at != saved_updated_category.updated_at}")

IO.puts("\n=== Testing Query Service Timestamp Handling ===")

# Read from query service
{:ok, query_category} = QueryCategoryRepo.find_by_id(category_id)
IO.puts("\nQuery Service Category:")
IO.inspect(query_category, pretty: true)
IO.puts("Created at: #{query_category.created_at}")
IO.puts("Updated at: #{query_category.updated_at}")

{:ok, query_product} = QueryProductRepo.find_by_id(product_id)
IO.puts("\nQuery Service Product:")
IO.inspect(query_product, pretty: true)
IO.puts("Created at: #{query_product.created_at}")
IO.puts("Updated at: #{query_product.updated_at}")

# Test statistics
{:ok, cat_stats} = QueryCategoryRepo.get_statistics()
IO.puts("\nCategory Statistics:")
IO.inspect(cat_stats, pretty: true)

{:ok, prod_stats} = QueryProductRepo.get_statistics()
IO.puts("\nProduct Statistics:")
IO.inspect(prod_stats, pretty: true)

# Cleanup
CommandProductRepo.delete(product_id)
CommandCategoryRepo.delete(category_id)

IO.puts("\n=== Test completed successfully! ===\n")