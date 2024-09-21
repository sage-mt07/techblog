# Define the base and overlay directories
$basePath = "base"
$overlaysPath = "overlays"
$outputMd = "resource_summary_with_check.md"

# Load node resource limits from an external JSON file
$nodeResourcesFile = "node_resources.json"
if (-Not (Test-Path $nodeResourcesFile)) {
    Write-Error "Node resources file not found: $nodeResourcesFile"
    exit 1
}

# Import node resources from the JSON file
$nodeResources = Get-Content $nodeResourcesFile | ConvertFrom-Json

# Function to parse CPU and memory from deployment.yaml
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
            $serviceResources[$serviceName] = @{ "cpu" = 0; "memory" = 0 }
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
    }

    return $serviceResources
}

# Function to run kustomize build and apply overlays
function Get-KustomizeResourceValues {
    param(
        [string]$overlayPath
    )

    # Run kustomize build to get the fully patched deployment.yaml
    $patchOutput = kustomize build $overlayPath

    # Save the output to a temporary YAML file
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $patchOutput

    # Extract resource values from the patched YAML
    return Get-ResourceValues -deploymentYamlPath $tempFile
}

# Get current date for resource check
$currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Initialize a hash table to hold resource summaries for each environment and each service
$resourceSummary = @{}

# Process base deployment
$baseDeploymentPath = Join-Path $basePath "deployment.yaml"
$baseResources = Get-ResourceValues -deploymentYamlPath $baseDeploymentPath
$resourceSummary["base"] = $baseResources

# Process overlays (dev, prod) and apply Kustomize patches
$overlays = Get-ChildItem -Path $overlaysPath -Directory
foreach ($overlay in $overlays) {
    $overlayResources = Get-KustomizeResourceValues -overlayPath $overlay.FullName
    $resourceSummary[$overlay.Name] = $overlayResources
}

# Generate the output in Markdown format with resource allocation checks
$outputContent = @"
# Kubernetes Resource Summary with Allocation Check

**Check Date:** $currentDate

| Environment | Service Name | CPU (cores) | Memory (Mi) | Allocation Status |
|-------------|--------------|-------------|-------------|-------------------|
"@

foreach ($env in $resourceSummary.Keys) {
    $totalCpu = 0
    $totalMemory = 0
    $allocationStatus = "OK"

    # Determine the resource limits for the current environment based on the number of hosts and their resources
    if ($nodeResources.ContainsKey($env)) {
        $hostCount = $nodeResources.$env.hosts
        $cpuPerHost = $nodeResources.$env.cpuPerHost
        $memoryPerHost = $nodeResources.$env.memoryPerHost
        $nodeTotalCpu = $hostCount * $cpuPerHost
        $nodeTotalMemory = $hostCount * $memoryPerHost
    } else {
        # Default values if environment-specific limits are not set
        $nodeTotalCpu = 4
        $nodeTotalMemory = 8192
    }

    foreach ($service in $resourceSummary[$env].Keys) {
        $cpu = $resourceSummary[$env][$service]["cpu"]
        $memory = $resourceSummary[$env][$service]["memory"]
        $totalCpu += $cpu
        $totalMemory += $memory

        # Check if the total resource allocation exceeds node capacity for each service
        $allocationStatusService = if ($totalCpu -le $nodeTotalCpu -and $totalMemory -le $nodeTotalMemory) {
            "OK"
        } else {
            "Exceeded"
        }

        # Append service information to the Markdown content
        $outputContent += "| $env | $service | $cpu | $memory | $allocationStatusService |`n"
    }

    # Add overall status for the environment
    $allocationStatusEnv = if ($totalCpu -gt $nodeTotalCpu -or $totalMemory -gt $nodeTotalMemory) {
        "Exceeded"
    } else {
        "OK"
    }
    
    $outputContent += "| $env (Total) | - | $totalCpu | $totalMemory | $allocationStatusEnv |`n"
}

# Write the result to a Markdown file
$outputContent | Set-Content -Path $outputMd

# Output result to console
Write-Output "Resource summary with allocation check saved to $outputMd"
