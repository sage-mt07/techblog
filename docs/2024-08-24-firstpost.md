# サービスの一覧とその依存関係を定義
$services = @{
    "serviceA" = @()          # serviceAは依存関係なし
    "serviceB" = @("serviceA") # serviceBはserviceAに依存
    "serviceC" = @()          # serviceCは依存関係なし
    "serviceD" = @("serviceB") # serviceDはserviceBに依存
}

# C:\RELEASE フォルダ内のすべての .yaml ファイルを取得
$releaseFolder = "C:\RELEASE"
$yamlFiles = Get-ChildItem -Path $releaseFolder -Filter *.yaml

# .yaml ファイルが存在するか確認
if ($yamlFiles.Count -eq 0) {
    Write-Host "No YAML files found in $releaseFolder. Exiting script."
    exit 1
}

# 依存関係がないサービスをリストアップ
$noDependencyServices = $services.GetEnumerator() | Where-Object { $_.Value.Count -eq 0 } | ForEach-Object { $_.Key }
# 依存関係があるサービスをリストアップ
$dependentServices = $services.GetEnumerator() | Where-Object { $_.Value.Count -gt 0 } | ForEach-Object { $_.Key }

# 並列で起動するための関数
function Start-ServicePodsInParallel {
    param (
        [string[]]$serviceNames
    )

    foreach ($serviceName in $serviceNames) {
        $yamlFile = $yamlFiles | Where-Object { $_.Name -eq "$serviceName.yaml" }
        if ($yamlFile) {
            Start-Job -ScriptBlock {
                Write-Host "Starting $using:serviceName using $using:yamlFile.FullName..."
                kubectl apply -f $using:yamlFile.FullName
                Write-Host "$using:serviceName is being started."
            }
        } else {
            Write-Host "YAML file for $serviceName not found. Skipping."
        }
    }
}

# 依存関係を持つサービスを順次起動する関数
function Start-ServicePods {
    param (
        [string]$serviceName
    )

    # サービスに依存するサービスがあれば、まずそれらを起動
    foreach ($dependency in $services[$serviceName]) {
        Start-ServicePods -serviceName $dependency
    }

    # サービスの YAML ファイルを探す
    $yamlFile = $yamlFiles | Where-Object { $_.Name -eq "$serviceName.yaml" }
    if ($yamlFile) {
        # サービスのPodを起動
        Write-Host "Starting $serviceName using $yamlFile.FullName..."
        kubectl apply -f $yamlFile.FullName

        # Podが完全に起動するのを待つ
        while ($true) {
            $podStatus = kubectl get pods -l app=$serviceName -o jsonpath='{.items[*].status.phase}'
            if ($podStatus -eq "Running") {
                Write-Host "$serviceName is up and running."
                break
            } else {
                Write-Host "Waiting for $serviceName to be fully operational..."
                Start-Sleep -Seconds 5
            }
        }
    } else {
        Write-Host "YAML file for $serviceName not found. Skipping."
    }
}

# 依存関係がないサービスを最初に並列で起動
Start-ServicePodsInParallel -serviceNames $noDependencyServices

# 依存関係があるサービスを順次起動
foreach ($service in $dependentServices) {
    Start-ServicePods -serviceName $service
}

Write-Host "All services have been triggered for startup."
