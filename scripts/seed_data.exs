# Seed script for testing the CQRS system

alias CommandService.Infrastructure.CommandBus
alias CommandService.Application.Commands.CategoryCommands.CreateCategory
alias CommandService.Application.Commands.ProductCommands.CreateProduct

# Start applications
{:ok, _} = Application.ensure_all_started(:command_service)
{:ok, _} = Application.ensure_all_started(:query_service)

IO.puts("Creating seed data...")

# Create categories
categories = [
  %{name: "Electronics", description: "Electronic devices and accessories"},
  %{name: "Books", description: "Books and publications"},
  %{name: "Clothing", description: "Apparel and fashion items"},
  %{name: "Food & Beverages", description: "Food and drink items"}
]

category_ids = Enum.map(categories, fn cat ->
  {:ok, command} = CreateCategory.validate(cat)
  {:ok, result} = CommandBus.dispatch(command)
  IO.puts("Created category: #{cat.name} with ID: #{result.id}")
  result.id
end)

# Create products
products = [
  %{name: "Laptop", price: 120000, category_id: Enum.at(category_ids, 0)},
  %{name: "Smartphone", price: 80000, category_id: Enum.at(category_ids, 0)},
  %{name: "Elixir in Action", price: 5000, category_id: Enum.at(category_ids, 1)},
  %{name: "Programming Phoenix", price: 4500, category_id: Enum.at(category_ids, 1)},
  %{name: "T-Shirt", price: 2500, category_id: Enum.at(category_ids, 2)},
  %{name: "Jeans", price: 8000, category_id: Enum.at(category_ids, 2)},
  %{name: "Coffee", price: 1200, category_id: Enum.at(category_ids, 3)},
  %{name: "Green Tea", price: 800, category_id: Enum.at(category_ids, 3)}
]

Enum.each(products, fn prod ->
  {:ok, command} = CreateProduct.validate(prod)
  {:ok, result} = CommandBus.dispatch(command)
  IO.puts("Created product: #{prod.name} with ID: #{result.id}")
end)

IO.puts("\nSeed data created successfully!")
IO.puts("\nYou can now test the system using the GraphQL endpoint at http://localhost:4000/graphql")