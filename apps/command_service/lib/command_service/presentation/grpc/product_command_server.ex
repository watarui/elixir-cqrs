defmodule CommandService.Presentation.Grpc.ProductCommandServer do
  @moduledoc """
  Product Command gRPC Server Implementation
  イベントソーシング対応版
  """

  use GRPC.Server, service: Proto.ProductCommand.Service

  alias CommandService.Application.Commands.ProductCommands.{
    CreateProduct,
    UpdateProduct,
    DeleteProduct
  }
  alias CommandService.Application.CommandBus
  alias Shared.Errors.GrpcErrorConverter
  alias Shared.Infrastructure.EventStore
  alias CommandService.Domain.Aggregates.ProductAggregate

  # Helper function to convert DateTime to Google.Protobuf.Timestamp
  defp datetime_to_timestamp(%DateTime{} = datetime) do
    seconds = DateTime.to_unix(datetime)
    nanos = datetime.microsecond |> elem(0) |> Kernel.*(1000)
    
    %Google.Protobuf.Timestamp{
      seconds: seconds,
      nanos: nanos
    }
  end

  def update_product(%Proto.ProductUpParam{} = request, _stream) do
    case request.crud do
      :INSERT ->
        handle_create_product(request)

      :UPDATE ->
        handle_update_product(request)

      :DELETE ->
        handle_delete_product(request)

      _ ->
        {:error, "Unknown CRUD operation"}
    end
  end

  # プライベート関数

  defp handle_create_product(%Proto.ProductUpParam{
         name: name,
         price: price,
         categoryId: category_id
       }) do
    # コマンドを作成
    command = CreateProduct.new(%{
      id: UUID.uuid4(),
      name: name,
      price: to_string(price),
      category_id: category_id,
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, result} ->
        # イベントから商品情報を復元
        product = build_product_from_result(result, command.id)
        response = %Proto.ProductUpResult{
          product: product,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_update_product(%Proto.ProductUpParam{
         id: id,
         name: name,
         price: price,
         categoryId: category_id
       }) do
    # コマンドを作成
    command = UpdateProduct.new(%{
      id: id,
      name: name,
      price: if(price && price != 0, do: to_string(price), else: nil),
      category_id: category_id,
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, result} ->
        # イベントから商品情報を復元
        product = build_product_from_result(result, id)
        response = %Proto.ProductUpResult{
          product: product,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_delete_product(%Proto.ProductUpParam{id: id}) do
    # コマンドを作成
    command = DeleteProduct.new(%{
      id: id,
      reason: "Deleted via gRPC",
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, _result} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  # イベントから商品情報を復元
  defp build_product_from_result(%{aggregate_id: aggregate_id}, default_id) do
    id = aggregate_id || default_id
    
    # イベントストアから最新の状態を取得
    case EventStore.read_aggregate_events(id) do
      {:ok, events} when events != [] ->
        # アグリゲートを復元
        aggregate = ProductAggregate.load_from_events(events)
        
        %Proto.Product{
          id: ProductAggregate.id(aggregate),
          name: ProductAggregate.name(aggregate),
          price: ProductAggregate.price(aggregate) |> Decimal.to_float() |> trunc(),
          category: nil  # TODO: カテゴリ情報も含める
        }
      
      _ ->
        # イベントが見つからない場合は基本情報を返す
        %Proto.Product{
          id: id,
          name: "",
          price: 0,
          category: nil
        }
    end
  end
end