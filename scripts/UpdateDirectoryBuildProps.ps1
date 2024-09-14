# File: script/UpdateDirectoryBuildProps.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$DirectoryBuildPropsPath,

    [Parameter(Mandatory = $true)]
    [string]$LatestPackagesCsvPath
)

# CSVファイルの読み込み
$packages = Import-Csv -Path $LatestPackagesCsvPath

# XMLとしてDirectory.Build.propsを読み込む、なければ新規作成
if (Test-Path $DirectoryBuildPropsPath) {
    [xml]$propsXml = Get-Content $DirectoryBuildPropsPath
} else {
    $propsXml = New-Object System.Xml.XmlDocument
    $projectElement = $propsXml.CreateElement("Project")
    $propsXml.AppendChild($projectElement) | Out-Null
}

# 既存のPackageReferenceをクリア
$existingPackageReferences = $propsXml.Project.ItemGroup.PackageReference
if ($existingPackageReferences) {
    $propsXml.Project.ItemGroup.RemoveChild($existingPackageReferences) | Out-Null
}

# 新しいPackageReferenceを追加
$itemGroup = $propsXml.CreateElement("ItemGroup")
foreach ($pkg in $packages) {
    $packageRef = $propsXml.CreateElement("PackageReference")
    $packageRef.SetAttribute("Include", $pkg.Package)
    $packageRef.SetAttribute("Version", $pkg.Version)
    $itemGroup.AppendChild($packageRef) | Out-Null
}
$propsXml.Project.AppendChild($itemGroup) | Out-Null

# 保存
$propsXml.Save($DirectoryBuildPropsPath)
Write-Host "Updated Directory.Build.props at $DirectoryBuildPropsPath"
