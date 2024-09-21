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
