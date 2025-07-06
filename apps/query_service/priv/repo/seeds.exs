# Query Service の初期データ（読み取り専用）

alias QueryService.Infrastructure.Database.Repo
alias QueryService.Infrastructure.Database.Schemas.{CategorySchema, ProductSchema}

# 既存のデータをクリア
Repo.delete_all(ProductSchema)
Repo.delete_all(CategorySchema)

# カテゴリのサンプルデータ
categories = [
  %{
    id: "1",
    name: "電子機器",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "2",
    name: "書籍",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "3",
    name: "衣類",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "4",
    name: "家具",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "5",
    name: "食品",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  }
]

# カテゴリをデータベースに挿入
Enum.each(categories, fn category ->
  Repo.insert!(CategorySchema.changeset(%CategorySchema{}, category))
end)

# 商品のサンプルデータ
products = [
  %{
    id: "1",
    name: "MacBook Pro",
    price: 299_000.00,
    category_id: "1",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "2",
    name: "iPhone 15",
    price: 120_000.00,
    category_id: "1",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "3",
    name: "Elixir プログラミング",
    price: 3500.00,
    category_id: "2",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "4",
    name: "Phoenix Framework ガイド",
    price: 4200.00,
    category_id: "2",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "5",
    name: "プログラマー用Tシャツ",
    price: 2800.00,
    category_id: "3",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "6",
    name: "エルゴノミクス椅子",
    price: 45000.00,
    category_id: "4",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  },
  %{
    id: "7",
    name: "コーヒー豆 100g",
    price: 1200.00,
    category_id: "5",
    inserted_at: ~N[2023-01-01 00:00:00],
    updated_at: ~N[2023-01-01 00:00:00]
  }
]

# 商品をデータベースに挿入
Enum.each(products, fn product ->
  Repo.insert!(ProductSchema.changeset(%ProductSchema{}, product))
end)

IO.puts("Query Service のシードデータ挿入が完了しました！")
IO.puts("- カテゴリ: #{length(categories)}件")
IO.puts("- 商品: #{length(products)}件")
