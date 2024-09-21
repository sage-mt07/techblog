# Kubernetes リソース割り当てチェックスクリプトのフォルダ構成と設定方法
Kubernetes クラスタ内の環境ごとのリソース割り当てをチェックするために、ホスト数および各ホストのCPU、メモリに基づいたリソース管理を行うPowerShellスクリプトを紹介します。本記事では、このスクリプトが前提とするフォルダ構成と設定ファイルの内容を詳しく解説します。

## フォルダ構成
以下のようなディレクトリ構成を前提としています。base と overlays のフォルダには、Kubernetesのリソース設定が含まれており、外部ファイル node_resources.json にはホスト数やリソース情報が保存されています。また、patch.yaml に環境ごとに異なる設定を定義し、これをKustomizeで適用します。
```
csharpコードをコピーする
project-root/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── patch.yaml
│   ├── prod/
│   │   ├── kustomization.yaml
│   │   ├── patch.yaml
├── node_resources.json
└── Generate-ResourceSummary.ps1

```
各ファイルの詳細
### 1. base/deployment.yaml & base/service.yaml
base/ フォルダには、デフォルトのKubernetesリソース定義（deployment.yaml、service.yaml）が含まれています。これらのファイルには、サービスのCPUやメモリリソースのリクエストやリミットを定義します。

例: deployment.yaml

```yamlコードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: my-app-container
        image: my-app-image:latest
        resources:
          requests:
            cpu: "500m"
            memory: "256Mi"
```

### 2. overlays/ フォルダ
overlays/ フォルダには、dev や prod などの環境ごとのKustomize設定ファイル（kustomization.yaml）と、ベースのリソース定義に対してパッチを適用する patch.yaml が含まれています。patch.yaml では、環境ごとに異なるリソース設定を行います。

例: dev/kustomization.yaml

```yamlコードをコピーする
resources:
  - ../../base/deployment.yaml
patchesStrategicMerge:
  - patch.yaml
```
例: prod/kustomization.yaml

```yamlコードをコピーする
resources:
  - ../../base/deployment.yaml
patchesStrategicMerge:
  - patch.yaml
```

例: dev/patch.yaml

```yamlコードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: my-app-container
        resources:
          requests:
            cpu: "600m"
            memory: "512Mi"
```
例: prod/patch.yaml

```yamlコードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 4
  template:
    spec:
      containers:
      - name: my-app-container
        resources:
          requests:
            cpu: "1000m"
            memory: "1Gi"
```
patch.yaml ファイルでは、base ディレクトリにある deployment.yaml の内容を上書きする形で、環境ごとのリソースやレプリカ数を変更しています。
### 3. node_resources.json
node_resources.json は、各環境（dev、prodなど）におけるホスト数と各ホストのCPU、メモリの情報を保存しているファイルです。この情報を基に、スクリプトは各環境に対して適切なリソース制限を計算します。

例: node_resources.json
```jsonコードをコピーする
{
  "dev": {
    "hosts": 2,
    "cpuPerHost": 2,
    "memoryPerHost": 4096
  },
  "prod": {
    "hosts": 4,
    "cpuPerHost": 8,
    "memoryPerHost": 16384
  }
}
```
### 4. Generate-ResourceSummary.ps1
このPowerShellスクリプトは、node_resources.json ファイルの情報を読み込み、Kubernetesのリソース割り当てをチェックします。サービスごとにリソースの割り当て状況を確認し、ホスト全体のリソース制限を超えないかをチェックします。

スクリプトの主な機能:
kustomize build コマンドでパッチ適用後のリソースを取得
各環境ごとにホスト数、CPU、メモリの制限を計算
リソース割り当てがホストのキャパシティを超えていないかチェック
Markdown形式で結果を出力
スクリプト実行方法
1. リポジトリのセットアップ
上記のフォルダ構成に従い、ファイルをセットアップします。

2. node_resources.json の作成
各環境ごとのホスト数やリソースの情報を設定した node_resources.json を作成します。このファイルには、環境ごとに異なるリソース制限を定義します。

3. PowerShellスクリプトの実行
PowerShellから Generate-ResourceSummary.ps1 を実行して、リソース割り当て状況を確認します。

```powershellコードをコピーする
.\Generate-ResourceSummary.ps1

```
4. Markdownファイルの確認
スクリプト実行後、resource_summary_with_check.md というファイルが生成され、各環境ごとのリソース割り当て結果が確認できます。以下は、出力結果の例です。

```markdownコードをコピーする
# Kubernetes Resource Summary with Allocation Check

**Check Date:** 2024-09-21 12:34:56
```
| Environment | Service Name | CPU (cores) | Memory (Mi) | Allocation Status |
|-------------|--------------|-------------|-------------|-------------------|
| dev         | my-app       | 1.2         | 1024        | OK                |
| dev         | my-db        | 0.6         | 2048        | OK                |
| dev (Total) | -            | 1.8         | 3072        | OK                |
| prod        | my-app       | 3           | 4096        | OK                |
| prod        | my-db        | 1.5         | 6144        | OK                |
| prod (Total)| -            | 4.5         | 10240       | OK                |