# ArgoCD 設定

このディレクトリには ArgoCD による GitOps デプロイメント設定が含まれています。

## セットアップ

1. ArgoCD をクラスタにインストール

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. ArgoCD CLI をインストール

```bash
brew install argocd
```

3. ArgoCD にログイン

```bash
# 初期パスワードを取得
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# ポートフォワード
kubectl port-forward svc/argocd-server -n argocd 8080:443

# ログイン
argocd login localhost:8080
```

4. プロジェクトとアプリケーションを作成

```bash
# プロジェクトを作成
kubectl apply -f argocd/project.yaml

# アプリケーションを作成
kubectl apply -f argocd/application.yaml
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-staging.yaml
```

## アプリケーション管理

### アプリケーションの同期

```bash
# 手動同期
argocd app sync elixir-cqrs

# 自動同期の有効化
argocd app set elixir-cqrs --sync-policy automated
```

### アプリケーションの状態確認

```bash
# アプリケーションの一覧
argocd app list

# 詳細情報
argocd app get elixir-cqrs

# リソースの確認
argocd app resources elixir-cqrs
```

### ロールバック

```bash
# 履歴の確認
argocd app history elixir-cqrs

# 特定のリビジョンにロールバック
argocd app rollback elixir-cqrs REVISION
```

## トラブルシューティング

### 同期エラーの確認

```bash
argocd app get elixir-cqrs --refresh
```

### ログの確認

```bash
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server
kubectl logs -n argocd deployment/argocd-application-controller
```

## セキュリティ

### RBAC の設定

`argocd-rbac-cm` ConfigMap を編集して RBAC ルールを設定：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    g, your-org:elixir-cqrs-developers, role:developer
```

### シークレット管理

本番環境では Sealed Secrets または External Secrets Operator の使用を推奨します。