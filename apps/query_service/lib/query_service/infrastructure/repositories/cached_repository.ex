defmodule QueryService.Infrastructure.Repositories.CachedRepository do
  @moduledoc """
  キャッシュ機能を持つリポジトリラッパー

  既存のリポジトリにキャッシング機能を追加します。
  """

  alias QueryService.Infrastructure.Cache.EtsCache
  require Logger

  @default_ttl :timer.minutes(5)

  @doc """
  キャッシュ付きでfind_by_id操作を実行します
  """
  @spec cached_find_by_id(module(), String.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def cached_find_by_id(repo, id, opts \\ []) do
    cache_key = build_cache_key(repo, :find_by_id, id)

    case EtsCache.get(cache_key) do
      {:ok, cached_value} ->
        Logger.debug("Cache hit for #{cache_key}")
        {:ok, cached_value}

      :not_found ->
        Logger.debug("Cache miss for #{cache_key}")

        # キャッシュされていない実装を呼び出す
        case apply(repo, :find_by_id_uncached, [id]) do
          {:ok, entity} = result ->
            ttl = Keyword.get(opts, :ttl, @default_ttl)
            EtsCache.put(cache_key, entity, ttl: ttl)
            result

          error ->
            error
        end
    end
  end

  @doc """
  キャッシュ付きでlist操作を実行します
  """
  @spec cached_list(module(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def cached_list(repo, opts \\ []) do
    cache_key = build_cache_key(repo, :list, :all)

    case EtsCache.get(cache_key) do
      {:ok, cached_value} ->
        Logger.debug("Cache hit for #{cache_key}")
        {:ok, cached_value}

      :not_found ->
        Logger.debug("Cache miss for #{cache_key}")

        # キャッシュされていない実装を呼び出す
        case apply(repo, :list_uncached, []) do
          {:ok, entities} = result ->
            ttl = Keyword.get(opts, :ttl, @default_ttl)
            EtsCache.put(cache_key, entities, ttl: ttl)
            result

          error ->
            error
        end
    end
  end

  @doc """
  特定のエンティティタイプのキャッシュを無効化します
  """
  @spec invalidate_cache(module()) :: :ok
  def invalidate_cache(repo) do
    pattern = {build_cache_prefix(repo) <> "*", :_, :_}
    EtsCache.delete_pattern(pattern)
    Logger.info("Cache invalidated for #{inspect(repo)}")
    :ok
  end

  @doc """
  特定のエンティティのキャッシュを無効化します
  """
  @spec invalidate_entity_cache(module(), String.t()) :: :ok
  def invalidate_entity_cache(repo, id) do
    cache_key = build_cache_key(repo, :find_by_id, id)
    EtsCache.delete(cache_key)

    # リスト全体のキャッシュも無効化
    list_key = build_cache_key(repo, :list, :all)
    EtsCache.delete(list_key)

    Logger.debug("Cache invalidated for entity #{id} in #{inspect(repo)}")
    :ok
  end

  # プライベート関数

  defp build_cache_key(repo, operation, identifier) do
    "#{build_cache_prefix(repo)}:#{operation}:#{identifier}"
  end

  defp build_cache_prefix(repo) do
    repo
    |> Module.split()
    |> List.last()
    |> String.downcase()
  end
end
