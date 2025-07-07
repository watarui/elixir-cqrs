defmodule CommandService.Presentation.Grpc.CategoryCommandServer do
  @moduledoc """
  Category Command gRPC Server Implementation
  イベントソーシング対応版
  """

  use GRPC.Server, service: Proto.CategoryCommand.Service

  alias CommandService.Application.Commands.CategoryCommands.{
    CreateCategory,
    UpdateCategory,
    DeleteCategory
  }
  alias CommandService.Application.CommandBus
  alias Shared.Errors.GrpcErrorConverter
  alias CommandService.Domain.Aggregates.CategoryAggregate
  alias Shared.Infrastructure.EventStore

  # Helper function to convert DateTime to Google.Protobuf.Timestamp
  defp datetime_to_timestamp(%DateTime{} = datetime) do
    seconds = DateTime.to_unix(datetime)
    nanos = datetime.microsecond |> elem(0) |> Kernel.*(1000)
    
    %Google.Protobuf.Timestamp{
      seconds: seconds,
      nanos: nanos
    }
  end

  defp datetime_to_timestamp(nil), do: nil

  def update_category(%Proto.CategoryUpParam{} = request, _stream) do
    case request.crud do
      :INSERT ->
        handle_create_category(request)

      :UPDATE ->
        handle_update_category(request)

      :DELETE ->
        handle_delete_category(request)

      _ ->
        {:error, "Unknown CRUD operation"}
    end
  end

  # プライベート関数

  defp handle_create_category(%Proto.CategoryUpParam{name: name}) do
    # コマンドを作成
    command = CreateCategory.new(%{
      id: UUID.uuid4(),
      name: name,
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, result} ->
        # イベントからカテゴリ情報を復元
        category = build_category_from_result(result, command.id, name)
        response = %Proto.CategoryUpResult{
          category: category,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_update_category(%Proto.CategoryUpParam{id: id, name: name}) do
    # コマンドを作成
    command = UpdateCategory.new(%{
      id: id,
      name: name,
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, result} ->
        # イベントからカテゴリ情報を復元
        category = build_category_from_result(result, id, name)
        response = %Proto.CategoryUpResult{
          category: category,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_delete_category(%Proto.CategoryUpParam{id: id}) do
    # コマンドを作成
    command = DeleteCategory.new(%{
      id: id,
      reason: "Deleted via gRPC",
      user_id: "grpc-user" # TODO: 実際のユーザーIDを使用
    })
    
    # コマンドバスで実行
    case CommandBus.execute(command) do
      {:ok, _result} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: GrpcErrorConverter.convert({:error, reason}),
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp build_category_from_result(result, id, name) do
    # 更新の場合は最新のカテゴリ情報を取得
    category = if result.events != [] do
      # イベントストアから最新の状態を取得
      case EventStore.read_aggregate_events(id) do
        {:ok, events} ->
          aggregate = CategoryAggregate.load_from_events(events)
          %Proto.Category{
            id: CategoryAggregate.id(aggregate) || id,
            name: CategoryAggregate.name(aggregate) || name
          }
        _ ->
          %Proto.Category{
            id: id,
            name: name
          }
      end
    else
      %Proto.Category{
        id: id,
        name: name
      }
    end
    
    category
  end
end