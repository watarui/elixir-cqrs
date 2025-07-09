# ビルドステージ
FROM elixir:1.18.1-otp-27-alpine AS builder

# ビルドに必要なパッケージをインストール
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    nodejs \
    npm

# 作業ディレクトリを設定
WORKDIR /app

# hex と rebar をインストール
RUN mix local.hex --force && \
    mix local.rebar --force

# 環境変数を設定
ENV MIX_ENV=prod

# 依存関係ファイルをコピー
COPY mix.exs mix.lock ./
COPY apps/client_service/mix.exs ./apps/client_service/
COPY apps/shared/mix.exs ./apps/shared/

# 依存関係をインストール
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# アプリケーションコードをコピー
COPY config config
COPY apps/shared apps/shared
COPY apps/client_service apps/client_service

# アセットをビルド（必要な場合）
# RUN cd apps/client_service/assets && \
#     npm install && \
#     npm run deploy && \
#     cd .. && \
#     mix phx.digest

# アプリケーションをコンパイル
RUN mix compile

# リリースを生成
RUN mix release client_service

# ランタイムステージ
FROM alpine:3.19

# ランタイムに必要なパッケージをインストール
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    ca-certificates

# アプリケーション用のユーザーを作成
RUN addgroup -g 1000 -S elixir && \
    adduser -u 1000 -S elixir -G elixir

# 作業ディレクトリを設定
WORKDIR /app

# リリースをコピー
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/client_service ./

# ユーザーを切り替え
USER elixir

# ポートを公開
EXPOSE 4000

# 環境変数
ENV PORT=4000
ENV PHX_HOST=localhost

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# アプリケーションを起動
CMD ["/app/bin/client_service", "start"]