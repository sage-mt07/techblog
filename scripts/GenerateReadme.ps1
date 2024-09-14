# File: script/GenerateReadme.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$ProjectDirectory
)

# プロジェクトのcsprojファイルを取得
$csprojFiles = Get-ChildItem -Path $ProjectDirectory -Filter *.csproj

foreach ($csproj in $csprojFiles) {
    Write-Host "Processing project: $($csproj.FullName)"
    
    # csprojファイルをXMLとして読み込む
    [xml]$projectXml = Get-Content $csproj.FullName
    
    # PackageReferenceを取得
    $packageReferences = $projectXml.Project.ItemGroup.PackageReference
    
    $packageList = @()

    foreach ($pkg in $packageReferences) {
        $packageName = $pkg.Include
        $currentVersion = $pkg.Version

        # 最新バージョンを取得
        try {
            $latestVersion = (nuget list $packageName -Source "https://api.nuget.org/v3/index.json" -AllVersions | Sort-Object -Descending | Select-Object -First 1).Trim()
            if (-not $latestVersion) {
                $latestVersion = "N/A"
            }
        }
        catch {
            Write-Warning "Failed to fetch latest version for package: $packageName"
            $latestVersion = "N/A"
        }

        $packageList += [PSCustomObject]@{
            Package = $packageName
            CurrentVersion = $currentVersion
            LatestVersion = $latestVersion
        }
    }

    # package.mdの内容を生成
    $readmeContent = @"
# Package Versions for $(($csproj.BaseName))

| Package | Current Version | Latest Version |
|---------|------------------|----------------|
"@

    foreach ($pkg in $packageList) {
        $readmeContent += "| $($pkg.Package) | $($pkg.CurrentVersion) | $($pkg.LatestVersion) |\n"
    }

    # package.mdに書き出す
    $readmePath = Join-Path -Path $ProjectDirectory -ChildPath "package.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8

    Write-Host "Generated package.md at $readmePath"
}
