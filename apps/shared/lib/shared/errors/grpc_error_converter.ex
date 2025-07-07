defmodule Shared.Errors.GrpcErrorConverter do
  @moduledoc """
  AppErrorをgRPC用のProto.Errorに変換するコンバータ
  
  AppErrorの型をgRPC互換のエラーコードと型にマッピングし、
  詳細情報を保持しながら適切なエラーレスポンスを生成します。
  """
  
  alias Shared.Errors.AppError
  
  # gRPCステータスコードの定義
  @grpc_status_ok 0
  @grpc_status_cancelled 1
  @grpc_status_unknown 2
  @grpc_status_invalid_argument 3
  @grpc_status_deadline_exceeded 4
  @grpc_status_not_found 5
  @grpc_status_already_exists 6
  @grpc_status_permission_denied 7
  @grpc_status_resource_exhausted 8
  @grpc_status_failed_precondition 9
  @grpc_status_aborted 10
  @grpc_status_out_of_range 11
  @grpc_status_unimplemented 12
  @grpc_status_internal 13
  @grpc_status_unavailable 14
  @grpc_status_data_loss 15
  @grpc_status_unauthenticated 16
  
  # AppError typeをgRPCエラータイプにマッピング
  @error_type_mapping %{
    validation_error: "VALIDATION_ERROR",
    not_found: "NOT_FOUND",
    conflict: "CONFLICT",
    unauthorized: "UNAUTHORIZED",
    forbidden: "FORBIDDEN",
    bad_request: "BAD_REQUEST",
    internal_error: "INTERNAL_ERROR",
    service_unavailable: "SERVICE_UNAVAILABLE",
    domain_error: "DOMAIN_ERROR",
    infrastructure_error: "INFRASTRUCTURE_ERROR"
  }
  
  # AppError typeをgRPCステータスコードにマッピング
  @status_code_mapping %{
    validation_error: @grpc_status_invalid_argument,
    not_found: @grpc_status_not_found,
    conflict: @grpc_status_already_exists,
    unauthorized: @grpc_status_unauthenticated,
    forbidden: @grpc_status_permission_denied,
    bad_request: @grpc_status_invalid_argument,
    internal_error: @grpc_status_internal,
    service_unavailable: @grpc_status_unavailable,
    domain_error: @grpc_status_failed_precondition,
    infrastructure_error: @grpc_status_internal
  }
  
  @doc """
  AppErrorをProto.Errorに変換します
  
  ## パラメータ
    - error: AppError構造体または通常のエラータプル
  
  ## 戻り値
    Proto.Error構造体
  """
  @spec convert(AppError.t() | {:error, any()}) :: Proto.Error.t()
  def convert(%AppError{type: type, message: message, details: details}) do
    formatted_message = if details do
      "#{message} | Details: #{inspect(details)}"
    else
      message
    end
    
    %Proto.Error{
      type: Map.get(@error_type_mapping, type, "UNKNOWN_ERROR"),
      message: formatted_message
    }
  end
  
  def convert({:error, :not_found}) do
    convert(%AppError{
      type: :not_found,
      message: "Resource not found",
      details: nil
    })
  end
  
  def convert({:error, reason}) when is_binary(reason) do
    %Proto.Error{
      type: "ERROR",
      message: reason
    }
  end
  
  def convert({:error, reason}) do
    %Proto.Error{
      type: "ERROR",
      message: inspect(reason)
    }
  end
  
  def convert(error) do
    %Proto.Error{
      type: "UNKNOWN_ERROR",
      message: "An unexpected error occurred: #{inspect(error)}"
    }
  end
  
  @doc """
  AppErrorからgRPCステータスコードを取得します
  
  ## パラメータ
    - error: AppError構造体
  
  ## 戻り値
    gRPCステータスコード（整数）
  """
  @spec get_status_code(AppError.t() | atom()) :: integer()
  def get_status_code(%AppError{type: type}) do
    Map.get(@status_code_mapping, type, @grpc_status_unknown)
  end
  
  def get_status_code(type) when is_atom(type) do
    Map.get(@status_code_mapping, type, @grpc_status_unknown)
  end
  
  def get_status_code(_), do: @grpc_status_unknown
  
  @doc """
  gRPC RPCErrorを生成します
  
  ## パラメータ
    - error: AppError構造体またはエラータプル
  
  ## 戻り値
    GRPC.RPCError構造体
  """
  @spec to_rpc_error(AppError.t() | {:error, any()}) :: GRPC.RPCError.t()
  def to_rpc_error(%AppError{} = error) do
    proto_error = convert(error)
    
    %GRPC.RPCError{
      status: get_status_code(error),
      message: proto_error.message
    }
  end
  
  def to_rpc_error(error) do
    proto_error = convert(error)
    status_code = if is_struct(error, AppError) do
      get_status_code(error)
    else
      @grpc_status_unknown
    end
    
    %GRPC.RPCError{
      status: status_code,
      message: proto_error.message
    }
  end
  
end