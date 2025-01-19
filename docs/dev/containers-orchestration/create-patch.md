---
layout: default
title: "2つの YAML ファイル間の差分を比較し、異なる部分を抽出（PowerShell版）"
category: "Containers Orchestration"
---
# 2つの YAML ファイル間の差分を比較し、異なる部分を抽出（PowerShell版）

このスクリプトでは、2つのファイルの異なる部分を検出し、dev_diff.yaml と prod_diff.yaml として、それぞれのファイルに含まれる差異を出力します。

Powershell Galleryからpowershell-yamlを取得します。
```
install-module powershell-yaml
```
PowerShell スクリプト
```powershell　コードをコピーする
# PSYaml モジュールのインポート
Import-Module powershell-yaml

# YAML ファイルの読み込み
$devYaml = ConvertFrom-Yaml (Get-Content -Path "dev.yaml" -Raw)
$prodYaml = ConvertFrom-Yaml (Get-Content -Path "prod.yaml" -Raw)

# YAML の比較（再帰的に差分を検出、リストや辞書型の詳細な比較）
function Compare-Yaml {
    param ($dev, $prod)

    $devDiff = @{}
    $prodDiff = @{}

    foreach ($key in $prod.Keys) {
        if ($dev.ContainsKey($key)) {
            # 値がハッシュテーブルの場合、再帰的に比較
            if ($dev[$key] -is [hashtable] -and $prod[$key] -is [hashtable]) {
                $nestedDevDiff, $nestedProdDiff = Compare-Yaml $dev[$key] $prod[$key]
                if ($nestedDevDiff.Count -gt 0) {
                    $devDiff[$key] = $nestedDevDiff
                }
                if ($nestedProdDiff.Count -gt 0) {
                    $prodDiff[$key] = $nestedProdDiff
                }
            }
            # 値がリストの場合、個々の要素を比較
            elseif ($dev[$key] -is [array] -and $prod[$key] -is [array]) {
                $listDevDiff, $listProdDiff = Compare-List $dev[$key], $prod[$key]
                if ($listDevDiff.Count -gt 0) {
                    $devDiff[$key] = $listDevDiff
                }
                if ($listProdDiff.Count -gt 0) {
                    $prodDiff[$key] = $listProdDiff
                }
            }
            # 値が異なる場合にパッチとして抽出
            elseif ($dev[$key] -ne $prod[$key]) {
                $devDiff[$key] = $dev[$key]
                $prodDiff[$key] = $prod[$key]
            }
        } else {
            # dev に存在しない場合、prod の新しい項目として prod_diff に追加
            $prodDiff[$key] = $prod[$key]
        }
    }

    # dev に存在するが prod に存在しない項目を dev_diff に追加
    foreach ($key in $dev.Keys) {
        if (-not $prod.ContainsKey($key)) {
            $devDiff[$key] = $dev[$key]
        }
    }

    return $devDiff, $prodDiff
}

# リストの比較関数（主に環境変数などで利用）
function Compare-List {
    param ($devList, $prodList)

    $devListDiff = @()
    $prodListDiff = @()

    foreach ($devItem in $devList) {
        $matchFound = $false

        foreach ($prodItem in $prodList) {
            # リスト内の各アイテムを比較し、一致するものがあればフラグを立てる
            if ($devItem.name -eq $prodItem.name -and $devItem.value -eq $prodItem.value) {
                $matchFound = $true
                break
            }
        }

        # dev に存在するが prod に存在しないものを dev_diff に追加
        if (-not $matchFound) {
            $devListDiff += $devItem
        }
    }

    foreach ($prodItem in $prodList) {
        $matchFound = $false

        foreach ($devItem in $devList) {
            if ($prodItem.name -eq $devItem.name -and $prodItem.value -eq $devItem.value) {
                $matchFound = $true
                break
            }
        }

        # prod に存在するが dev に存在しないものを prod_diff に追加
        if (-not $matchFound) {
            $prodListDiff += $prodItem
        }
    }

    return $devListDiff, $prodListDiff
}

# 差分を取得
$devDiff, $prodDiff = Compare-Yaml $devYaml $prodYaml

# dev 側の差分を書き込み
$devDiff | ConvertTo-Yaml | Out-File -FilePath "dev_diff.yaml"

# prod 側の差分を書き込み
$prodDiff | ConvertTo-Yaml | Out-File -FilePath "prod_diff.yaml"

Write-Host "差分ファイルが生成されました: dev_diff.yaml と prod_diff.yaml"
```

## 1. 実行結果
このスクリプトを実行すると、dev.yaml と prod.yaml の間で異なる部分がそれぞれ dev_diff.yaml と prod_diff.yaml に書き出されます。

dev.yaml
```yamlコードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app:dev
          env:
            - name: ENVIRONMENT
              value: dev
            - name: DEBUG
              value: "true"
          ports:
            - containerPort: 80
```
prod.yaml
```yamlコードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 5
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app:prod
          env:
            - name: ENVIRONMENT
              value: prod
            - name: LOG_LEVEL
              value: "info"
          ports:
            - containerPort: 80
```

## 2. 生成される dev_diff.yaml
dev.yaml にしか存在しない、または異なる部分が出力されます。

```yamlコードをコピーする
spec:
  replicas: 2
  template:
    spec:
      containers:
      - image: my-app:dev
        env:
        - name: ENVIRONMENT
          value: dev
        - name: DEBUG
          value: true
```

## 3. 生成される prod_diff.yaml
prod.yaml にしか存在しない、または異なる部分が出力されます。

```yamlコードをコピーする
spec:
  replicas: 5
  template:
    spec:
      containers:
      - image: my-app:prod
        env:
        - name: ENVIRONMENT
          value: prod
        - name: LOG_LEVEL
          value: info
```
## 4. スクリプトの動作説明

- Compare-Yaml 関数: dev.yaml と prod.yaml を再帰的に比較し、それぞれのファイルにしか存在しない、または異なる項目を dev_diff.yaml と prod_diff.yaml に振り分けます。
- Compare-List 関数: 環境変数のようなリスト型データを個別に比較し、一致しない部分だけを dev_diff または prod_diff に追加します。
- 差分出力: 結果として、2つのファイル間の差異のみを別々のファイルとして出力します。これにより、両ファイルの相違点を明確に確認することができます。
