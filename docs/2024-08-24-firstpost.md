# C:\RELEASE フォルダ内のすべての .yaml ファイルを取得
$releaseFolder = "C:\RELEASE"
$yamlFiles = Get-ChildItem -Path $releaseFolder -Filter *.yaml

# .yaml ファイルが存在するか確認
if ($yamlFiles.Count -eq 0) {
    Write-Host "No YAML files found in $releaseFolder. Exiting script."
    exit 1
}

# 正規表現でファイル名からサービス名と名前空間を抽出
function Parse-ServiceName {
    param (
        [string]$fileName
    )
    
    if ($fileName -match '^(?<ServiceName>[^_]+)_(?<Namespace>[^_]+)_\d{8}\d{2}\.yaml$') {
        return $matches['ServiceName']
    }
    return $null
}

# サービス名ごとに分類
$services = @{}
foreach ($yamlFile in $yamlFiles) {
    $serviceName = Parse-ServiceName $yamlFile.Name
    if ($serviceName) {
        if (-not $services.ContainsKey($serviceName)) {
            $services[$serviceName] = @()  # 依存関係の初期化
        }
    } else {
        Write-Host "YAML file $($yamlFile.Name) does not match expected naming convention. Skipping."
    }
}

# 依存関係がないサービスと依存関係があるサービスを分類
$noDependencyServices = @()
$dependentServices = @()

foreach ($service in $services.Keys) {
    $dependencies = $services[$service]
    if ($dependencies.Count -eq 0) {
        $noDependencyServices += $service
    } else {
        $dependentServices += $service
    }
}

# 並列で起動するための関数
function Start-ServicePodsInParallel {
    param (
        [string[]]$serviceNames
    )

    foreach ($serviceName in $serviceNames) {
        $yamlFile = $yamlFiles | Where-Object { Parse-ServiceName($_.Name) -eq $serviceName }
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

    # サービスの YAML ファイルを探す
    $yamlFile = $yamlFiles | Where-Object { Parse-ServiceName($_.Name) -eq $serviceName }
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
