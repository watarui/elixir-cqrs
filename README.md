## 前提条件

- **Elixir** 1.15 以上
- **Erlang/OTP** 25 以上
- **Docker** & Docker Compose
- **PostgreSQL** クライアント（`psql`、`pg_isready`）
- **Bun**

## 起動

```sh
./scripts/start_all.sh --with-frontend --with-demo-data
```

## 停止

```sh
./scripts/stop_all.sh --all
```
