# Kubernetesで依存関係のあるサービスを順番に起動・停止するPowerShellスクリプト

Kubernetes環境で複数のサービスを展開する場合、サービス間に依存関係が存在することがあります。例えば、あるサービスが他のサービスに依存している場合、その依存関係を考慮して順番に起動する必要があります。また、サービスが複数のレプリカで構成されている場合でも、すべてのレプリカが正常に起動するまで待機することが重要です。この記事では、依存関係のあるサービスを順番に起動・停止し、起動完了を待機するPowerShellスクリプトを紹介します。

# 前提条件

- 各サービスのKubernetesデプロイメントは、service_環境名_日付.yaml という形式のYAMLファイルで管理されています。
- サービスには依存関係があり、依存関係のあるサービスは順番に起動される必要があります。
- 各サービスが完全に起動するまで待機し、正常に動作していることを確認します。
- 依存関係のあるサービスの起動スクリプト
- 依存関係のあるサービスを順番に起動し、サービスが正常に起動するまで待機するスクリプトです。以下のポイントを押さえています。

kubectl apply コマンドでYAMLファイルを適用してサービスをデプロイします。

各サービスの起動完了を kubectl rollout status コマンドで確認し、すべてのレプリカが正常に動作するまで待機します。
依存関係のないサービスも自動的に特定し、それぞれ順番に起動します。
PowerShellスクリプト: Deploy-Services.ps1
```powershell コードをコピーする
# 最新のyamlファイルを取得する関数
function Get-LatestYamlFile {
    param (
        [string]$serviceName,
        [string]$environment
    )
    # 最新の日付のファイル名を取得
    $files = Get-ChildItem -Path . -Filter "$serviceName" + "_" + $environment + "_*.yaml" | Sort-Object Name -Descending
    return $files[0].FullName
}
# 依存関係のあるサービスを事前定義
$dependentServices = @("serviceA", "serviceB", "serviceC")
$environment = "dev"

# 依存関係のあるサービスを順番に起動し、起動完了を待機
foreach ($service in $dependentServices) {
    $yamlFile = Get-LatestYamlFile -serviceName $service -environment $environment
    if ($yamlFile) {
        Write-Host "Deploying dependent service: $service with $yamlFile"
        kubectl apply -f $yamlFile
        # サービスの起動が完了するまで待機
        kubectl rollout status deployment/$service -n $environment
    } else {
        Write-Host "No YAML file found for $service in $environment environment."
    }
}

# 依存関係のないサービスを自動的に特定し、並行して起動し、起動完了を待機
$allServiceFiles = Get-ChildItem -Path . -Filter "*_$environment_*.yaml"
$independentServices = $allServiceFiles | Where-Object { $dependentServices -notcontains $_.BaseName.Split("_")[0] }

foreach ($file in $independentServices) {
    Write-Host "Deploying independent service with $($file.FullName)"
    kubectl apply -f $file.FullName
    # サービスの起動が完了するまで待機
    $serviceName = $file.BaseName.Split("_")[0]
    kubectl rollout status deployment/$serviceName -n $environment
}

Write-Host "All services have been deployed."
```

依存関係のあるサービスの停止スクリプト
同様に、サービスを停止する際にも依存関係を考慮し、順番に停止します。このスクリプトは、kubectl delete コマンドを使用してサービスを削除します。

```PowerShellスクリプト: Stop-Services.ps1
powershell
コードをコピーする
# 最新のyamlファイルを取得する関数
function Get-LatestYamlFile {
    param (
        [string]$serviceName,
        [string]$environment
    )
    # 最新の日付のファイル名を取得
    $files = Get-ChildItem -Path . -Filter "$serviceName" + "_" + $environment + "_*.yaml" | Sort-Object Name -Descending
    return $files[0].FullName
}

# 依存関係のあるサービスを事前定義
$dependentServices = @("serviceA", "serviceB", "serviceC")
$environment = "dev"

# 依存関係のあるサービスを順番に停止
foreach ($service in $dependentServices) {
    $yamlFile = Get-LatestYamlFile -serviceName $service -environment $environment
    if ($yamlFile) {
        Write-Host "Stopping dependent service: $service with $yamlFile"
        kubectl delete -f $yamlFile
    } else {
        Write-Host "No YAML file found for $service in $environment environment."
    }
}

# 依存関係のないサービスを自動的に特定し、並行して停止
$allServiceFiles = Get-ChildItem -Path . -Filter "*_$environment_*.yaml"
$independentServices = $allServiceFiles | Where-Object { $dependentServices -notcontains $_.BaseName.Split("_")[0] }

foreach ($file in $independentServices) {
    Write-Host "Stopping independent service with $($file.FullName)"
    kubectl delete -f $file.FullName
}

Write-Host "All services have been stopped."
```

## スクリプトのポイント

- 依存関係の管理: 事前に定義された依存関係をもとに、サービスを順番に起動・停止します。
- 起動完了の待機: 各サービスが完全に起動するまで kubectl rollout status を使用して確認します。
- 並行処理の排除: 依存関係がある場合、サービスの起動が完全に完了するまで次のサービスの起動は行いません。
- 自動ファイル選択: 最新の日付のYAMLファイルを自動で取得し、それを使用してデプロイ・削除します。