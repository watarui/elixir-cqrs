# Command Service Dockerfile
FROM elixir:1.18-alpine

# 必要なパッケージをインストール
RUN apk add --no-cache build-base git postgresql-client

# 作業ディレクトリを設定
WORKDIR /app

# 依存関係ファイルをコピー
COPY mix.exs mix.lock ./
COPY apps/command_service/mix.exs ./apps/command_service/
COPY apps/shared/mix.exs ./apps/shared/

# 依存関係をインストール
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

# アプリケーションコードをコピー
COPY . .

# start.shスクリプトをコピー
COPY docker/command_service/start.sh /start.sh
RUN chmod +x /start.sh

# プロトコルバッファーを生成（既に生成済みのファイルを使用）
# RUN cd apps/shared && ./proto/generate_elixir.sh

# 依存関係を再インストール（全環境対応）
RUN mix deps.get --only dev && mix deps.get --only test && mix deps.get --only prod

# アプリケーションをコンパイル
RUN MIX_ENV=dev mix compile

# ポート50051を公開
EXPOSE 50051

# アプリケーションを起動
CMD ["/start.sh"] 