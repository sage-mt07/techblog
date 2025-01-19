---
layout: default
title: "Kubernetes リソース管理: ホストごとのリソース割り当てと詳細表"
category: "Containers Orchestration"
---
# Kubernetes リソース管理: ホストごとのリソース割り当てと詳細表
Kubernetes クラスタを運用する際、ホストごとのリソース使用率や、各ホストに割り当てられたネームスペースおよびサービスの詳細情報を把握することは、効率的なリソース管理に欠かせません。本記事では、ホストごとのリソース割り当て表と、各ホストに割り当てられたネームスペース・サービスの詳細表を作成する方法について解説します。

## 1. フォルダ構成とリソース設定
まず、今回のリソース管理に基づいたフォルダ構成を以下に示します。project-root/ フォルダの下に、ネームスペースごとのフォルダがあり、それぞれのフォルダ内に環境ごとの設定が含まれています。さらに、ホストごとのリソース情報は node_resources.json ファイルで管理します。

```フォルダ構成
arduino
コードをコピーする
project-root/
├── namespace-1/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   ├── overlays/
│   │   ├── dev/
│   │   │   ├── kustomization.yaml
│   │   ├── prod/
│   │   │   ├── kustomization.yaml
├── namespace-2/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   ├── overlays/
│   │   ├── dev/
│   │   │   ├── kustomization.yaml
│   │   ├── prod/
│   │   │   ├── kustomization.yaml
├── node_resources.json
└── Generate-ResourceSummary.ps1
```
- project-root/: Kubernetes プロジェクトのルートフォルダ。
- namespace-1/, namespace-2/: ネームスペースごとのフォルダ。それぞれのネームスペースに関連する Kubernetes 設定が含まれています。
- base/: 各ネームスペースにおけるデフォルトのリソース設定（例：deployment.yaml や service.yaml）。
- overlays/: 環境別のオーバーレイ設定が含まれます（例：dev/, prod/）。
- node_resources.json: 各ホストのリソース情報（CPU、メモリ）を管理するファイル。
- Generate-ResourceSummary.ps1: リソース割り当てと詳細情報を出力するスクリプト。
node_resources.json の例
各ホストごとのリソース（CPU、メモリ）とホスト数を設定します。

```jsonコードをコピーする
{
  "namespace-1": {
    "hosts": 2,
    "cpuPerHost": 4,
    "memoryPerHost": 8192
  },
  "namespace-2": {
    "hosts": 2,
    "cpuPerHost": 4,
    "memoryPerHost": 8192
  }
}
```
- hosts: 各ネームスペースにおけるホスト数。
- cpuPerHost: 各ホストに割り当てられる CPU コア数。
- memoryPerHost: 各ホストに割り当てられるメモリ量（MiB単位）。
## 2. リソース管理スクリプト
このスクリプトでは、以下の2つの表を生成します。

ホストごとのリソース割り当て表：ホストごとの CPU、メモリの割り当てを表示します。
詳細表：ホストごとに割り当てられたネームスペースとサービスの一覧を示します。
スクリプトの内容
以下は、リソース割り当てと詳細表を生成するPowerShellスクリプトです。

```powershellコードをコピーする
# Define the base and overlay directories
$projectRoot = "project-root"
$outputMd = "resource_summary_with_host_details.md"

# Load node resource limits from an external JSON file
$nodeResourcesFile = Join-Path $projectRoot "node_resources.json"
if (-Not (Test-Path $nodeResourcesFile)) {
    Write-Error "Node resources file not found: $nodeResourcesFile"
    exit 1
}

# Import node resources from the JSON file
$nodeResources = Get-Content $nodeResourcesFile | ConvertFrom-Json

# Function to parse maxSkew, CPU, and memory from deployment.yaml
function Get-ResourceValues {
    param(
        [string]$deploymentYamlPath
    )
    
    # Initialize a hash table for each service
    $serviceResources = @{}

    # Read the deployment YAML (either a base or patched version)
    $yamlContent = Get-Content $deploymentYamlPath | Out-String | ConvertFrom-Yaml

    # Extract resource requests and limits for each container
    foreach ($container in $yamlContent.spec.template.spec.containers) {
        $serviceName = $yamlContent.metadata.name

        # Initialize service resource if not exists
        if (-not $serviceResources.ContainsKey($serviceName)) {
            $serviceResources[$serviceName] = @{ "cpu" = 0; "memory" = 0; "maxSkew" = 1 }
        }

        if ($container.resources.requests.cpu) {
            $cpuValue = [double]$container.resources.requests.cpu.Replace('m','') / 1000
            $serviceResources[$serviceName]["cpu"] += $cpuValue
        }

        if ($container.resources.requests.memory) {
            $memoryValue = $container.resources.requests.memory
            $memoryMi = if ($memoryValue -like "*Mi") { 
                [double]$memoryValue.Replace('Mi','') 
            } elseif ($memoryValue -like "*Gi") { 
                [double]$memoryValue.Replace('Gi','') * 1024 
            }
            $serviceResources[$serviceName]["memory"] += $memoryMi
        }

        # Extract maxSkew from topologySpreadConstraints
        foreach ($constraint in $yamlContent.spec.template.spec.topologySpreadConstraints) {
            if ($constraint.maxSkew) {
                $serviceResources[$serviceName]["maxSkew"] = [double]$constraint.maxSkew
            }
        }
    }

    return $serviceResources
}

# Initialize the output for Markdown format
$outputContent = @"
# Kubernetes Host Resource Allocation Summary

"@

# Add detailed table for host to namespace and service allocation
$detailedTable = @"
# Kubernetes Host Allocation Details

"@

# Process each namespace
$namespaces = Get-ChildItem -Path $projectRoot -Directory
foreach ($namespace in $namespaces) {
    # Process base deployment for each namespace
    $baseDeploymentPath = Join-Path $namespace.FullName "base/deployment.yaml"
    $namespaceResources = Get-ResourceValues -deploymentYamlPath $baseDeploymentPath

    # Host allocation details
    $hostCount = $nodeResources.$namespace.Name.hosts
    $cpuPerHost = $nodeResources.$namespace.Name.cpuPerHost
    $memoryPerHost = $nodeResources.$namespace.Name.memoryPerHost
    $totalCpu = ($namespaceResources | Measure-Object -Property cpu -Sum).Sum
    $totalMemory = ($namespaceResources | Measure-Object -Property memory -Sum).Sum
    $cpuUsagePerHost = $totalCpu / $hostCount
    $memoryUsagePerHost = $totalMemory / $hostCount
    $hostCpuUsagePercent = ($cpuUsagePerHost / $cpuPerHost) * 100
    $hostMemoryUsagePercent = ($memoryUsagePerHost / $memoryPerHost) * 100

    # Append host allocation to the host allocation table
    for ($i = 1; $i -le $hostCount; $i++) {
        $outputContent += "| Host-$i | $([math]::Round($cpuUsagePerHost, 2)) cores | $([math]::Round($memoryUsagePerHost, 2)) Mi |`n"
    }

    # Append detailed allocation to the detailed table
    foreach ($service in $namespaceResources.Keys) {
        $cpu = $namespaceResources[$service]["cpu"]
        $memory = $namespaceResources[$service]["memory"]
        for ($i = 1; $i -le $hostCount; $i++) {
            $detailedTable += "| Host-$i | $namespace.Name | $service | $cpu cores | $memory Mi |`n"
        }
    }
}

# Combine host allocation table and detailed allocation table into the output content
$outputContent += $detailedTable

# Write the result to a Markdown file
$outputContent | Set-Content -Path $outputMd

# Output result to console
Write-Output "Resource summary with host details saved to $outputMd"
```
## 3. 実行手順
リポジトリのセットアップ
project-root/ フォルダの構成に従い、各ネームスペースごとのフォルダとサービスの YAML ファイルを配置します。各サービスの YAML ファイルに maxSkew を設定し、node_resources.json でホストのリソース情報を管理します。

スクリプトの実行
PowerShell から以下のコマンドでスクリプトを実行します。

```powershellコードをコピーする
.\Generate-ResourceSummary.ps1
```
結果の確認
実行後、resource_summary_with_host_details.md という Markdown ファイルが生成され、ホストごとのリソース割り当て表と詳細表が確認できます。

## 4. 出力例（Markdown形式）
ホストごとのリソース割り当て表

```markdownコードをコピーする
# Kubernetes Host Resource Allocation Summary
```
| Host   | CPU Allocation (cores) | Memory Allocation (Mi) |
|--------|------------------------|------------------------|
| Host-1 | 2.00                   | 1024.00                |
| Host-2 | 2.00                   | 1024.00                |


詳細表：ホストごとのネームスペース・サービス割り当て

```markdownコードをコピーする
# Kubernetes Host Allocation Details
```

| Host   | Namespace   | Service Name | CPU (cores) | Memory (Mi) |
|--------|-------------|--------------|-------------|-------------|
| Host-1 | namespace-1 | my-app       | 1.5         | 512         |
| Host-2 | namespace-1 | my-app       | 1.5         | 512         |
| Host-1 | namespace-1 | my-db        | 0.5         | 1024        |
| Host-2 | namespace-1 | my-db        | 0.5         | 1024        |
| Host-1 | namespace-2 | my-api       | 2.0         | 2048        |
| Host-2 | namespace-2 | my-api       | 2.0         | 2048        |
