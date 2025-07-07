defmodule Shared.Domain.Repository do
  @moduledoc """
  リポジトリの基本インターフェース
  
  すべてのリポジトリが実装すべき基本的な操作を定義します。
  """
  
  alias Shared.Errors.AppError
  
  @doc """
  エンティティを保存します
  
  ## パラメータ
    - entity: 保存するエンティティ
  
  ## 戻り値
    - {:ok, entity} - 保存成功
    - {:error, AppError.t()} - 保存失敗
  """
  @callback save(entity :: struct()) :: {:ok, struct()} | {:error, AppError.t()}
  
  @doc """
  IDでエンティティを検索します
  
  ## パラメータ
    - id: エンティティのID
  
  ## 戻り値
    - {:ok, entity} - エンティティが見つかった場合
    - {:error, AppError.t()} - エンティティが見つからない場合
  """
  @callback find_by_id(id :: String.t()) :: {:ok, struct()} | {:error, AppError.t()}
  
  @doc """
  エンティティを更新します
  
  ## パラメータ
    - entity: 更新するエンティティ
  
  ## 戻り値
    - {:ok, entity} - 更新成功
    - {:error, AppError.t()} - 更新失敗
  """
  @callback update(entity :: struct()) :: {:ok, struct()} | {:error, AppError.t()}
  
  @doc """
  IDでエンティティを削除します
  
  ## パラメータ
    - id: 削除するエンティティのID
  
  ## 戻り値
    - :ok - 削除成功
    - {:error, AppError.t()} - 削除失敗
  """
  @callback delete(id :: String.t()) :: :ok | {:error, AppError.t()}
  
  @doc """
  すべてのエンティティを取得します
  
  ## 戻り値
    - {:ok, [entity]} - エンティティのリスト
    - {:error, AppError.t()} - 取得失敗
  """
  @callback list() :: {:ok, [struct()]} | {:error, AppError.t()}
  
  @doc """
  IDでエンティティが存在するか確認します
  
  ## パラメータ
    - id: 確認するエンティティのID
  
  ## 戻り値
    - boolean - 存在する場合true
  """
  @callback exists?(id :: String.t()) :: boolean()
  
  @doc """
  条件に一致するエンティティの数を取得します
  
  ## パラメータ
    - conditions: 検索条件のマップ
  
  ## 戻り値
    - {:ok, count} - カウント成功
    - {:error, AppError.t()} - カウント失敗
  """
  @callback count(conditions :: map()) :: {:ok, non_neg_integer()} | {:error, AppError.t()}
  
  @doc """
  トランザクション内で操作を実行します
  
  ## パラメータ
    - fun: トランザクション内で実行する関数
  
  ## 戻り値
    - {:ok, result} - トランザクション成功
    - {:error, AppError.t()} - トランザクション失敗
  """
  @callback transaction(fun :: function()) :: {:ok, any()} | {:error, AppError.t()}
  
  @optional_callbacks [count: 1, transaction: 1]
end