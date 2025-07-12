# Scripts ディレクトリの構成

## 🚀 主要な起動・停止スクリプト

### start_all.sh
すべてのサービス（Docker インフラ + Elixir サービス）を起動

### stop_all.sh
すべてのサービスを停止

### start_services.sh
Elixir サービスのみ起動（Docker は起動済みが前提）

### stop_services.sh
Elixir サービスのみ停止

### setup_infra.sh
Docker インフラのみ起動

## 📊 データベース管理

### setup_db.sh
データベースの初期セットアップ（マイグレーション実行）

### seed_demo_data.exs
デモデータの投入（最新版）

### clear_data.sh
データベースのデータをクリア

### check_db_status.sh
データベースの状態を確認

## 🔧 メンテナンス・デバッグ

### rebuild_projections_direct.exs
Event Store から Query DB へのプロジェクション再構築（直接SQL版）

### check_health.sh
各サービスのヘルスチェック

### cleanup_sagas.exs
失敗した SAGA のクリーンアップ

## 🗑️ 削除候補（古いまたは重複）

- rebuild_projections.exs （古い）
- rebuild_projections_http.exs （不要）
- rebuild_projections_manual.exs （不要）
- rebuild_projections_simple.exs （不要）
- seed_demo_data_old.exs （古い）
- seed_demo_data_simple.exs （古い）
- debug_events.exs （一時的なデバッグ用）
- run_seed_data.sh （seed_demo_data.exs で十分）

## 推奨される使い方

1. **初回セットアップ**
   ```bash
   ./scripts/start_all.sh
   ./scripts/setup_db.sh
   mix run scripts/seed_demo_data.exs
   ```

2. **日常的な起動・停止**
   ```bash
   ./scripts/start_all.sh
   ./scripts/stop_all.sh
   ```

3. **データリセット**
   ```bash
   ./scripts/clear_data.sh
   mix run scripts/seed_demo_data.exs
   ```

4. **プロジェクション再構築**
   ```bash
   mix run scripts/rebuild_projections_direct.exs
   ```