# File: Scripts/UpdatePackageReferences.ps1

param (

    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,

    [Parameter(Mandatory = $true)]
    [string]$PackageOutputDir
)

# === 1. 組織名、プロジェクト名、リポジトリIDの取得 ===

# System.TeamFoundationCollectionUri から組織名を抽出
$collectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI

if ($collectionUri -match "https://dev\.azure\.com/(?<organization>[^/]+)/") {
    $organization = $matches['organization']
} else {
    Write-Error "組織名を URI から抽出できませんでした。"
    exit 1
}

# プロジェクト名とリポジトリIDを取得
$project = $env:SYSTEM_TEAMPROJECT
$repositoryId = $env:BUILD_REPOSITORY_ID

Write-Host "組織名: $organization"
Write-Host "プロジェクト名: $project"
Write-Host "リポジトリID: $repositoryId"
Write-Host "PackageOutputDir: $PackageOutputDir"

# === 2. .nupkg ファイルの取得 ===

# 生成された .nupkg ファイルを取得
$latestNupkg = Get-ChildItem -Path $PackageOutputDir -Filter *.nupkg | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $latestNupkg) {
    Write-Error ".nupkg ファイルが生成されていません。nuget pack が成功したか確認してください。"
    exit 1
}
$latestNupkgPath=$latestNupkg.FullName
Write-Host "最新の .nupkg ファイル: $($latestNupkgPath)"

# === 3. PowerShellモジュールのインポート ===

# モジュールのパス（スクリプトと同じディレクトリに配置）
$modulePath = "$PSScriptRoot/packageUtils.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Error "モジュールファイルが見つかりません: $modulePath"
    exit 1
}

Import-Module $modulePath

# === 4. パッケージ情報の取得 ===

Write-Host "最新の .nupkg ファイル: $($latestNupkgPath)"


$packageInfo = Get-PackageInfoFromNupkg -Path $latestNupkgPath

if ($null -eq $packageInfo) {
    Write-Error "パッケージ情報の取得に失敗しました。"
    exit 1
}

$packageName = $packageInfo.Name
$packageVersion = $packageInfo.Version

Write-Host "パッケージ名: $packageName"
Write-Host "パッケージバージョン: $packageVersion"

# === 5. 他の .csproj ファイルの更新 ===

# 更新対象の .csproj ファイルを取得（自分自身のプロジェクトを除外）
$csprojFiles = Get-ChildItem -Path . -Recurse -Filter *.csproj 

# プロジェクトファイルの更新
foreach ($file in $csprojFiles) {
    [xml]$xmlContent = Get-Content $file.FullName

    # PackageReference ノードを検索
    $packageReferences = $xmlContent.Project.ItemGroup.PackageReference | Where-Object { $_.Include -eq $packageName }

    if ($packageReferences) {
        foreach ($pr in $packageReferences) {
            $pr.Version = $packageVersion
            Write-Host "$($file.FullName) の PackageReference '$packageName' をバージョン '$packageVersion' に更新しました。"
        }
        # 更新されたXMLを保存
        $xmlContent.Save($file.FullName)
    } else {
        Write-Host "$($file.FullName) にはパッケージ '$packageName' の参照がありません。"
    }
}


# === 7. Git の設定とコミット ===

$buildId=$env:BUILD_BUILDID
git config user.email "build@yourdomain.com"
git config user.name "Build Agent"

# 新しいブランチの作成と変更のコミット
$branchName = "pr/update-package-version-$buildId"
git checkout -b $branchName
git add **/*.csproj
git commit -m "Update package references to $packageName $packageVersion"

Write-Host "git commit"

# === 8. 変更のプッシュ ===
# 環境変数から System.AccessToken を取得
$accessToken = $env:SYSTEM_ACCESSTOKEN

# git remote set-url origin https://$AccessToken@dev.azure.com/$organization/$project/_git/$repositoryId

git push origin $branchName

Write-Host "git push"


# === 9. プルリクエストの作成 ===


# 認証ヘッダーの作成（Bearer 認証を使用）
$headers = @{
    Authorization = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# ビルドサービスアカウントの ID を取得
$profileUrl = "https://vssps.dev.azure.com/$organization/_apis/connectionData?connectOptions=none&lastChangeId=-1&lastChangeId64=-1"
$profileResponse = Invoke-RestMethod -Method Get -Uri $profileUrl -Headers $headers
$buildServiceAccountId = $profileResponse.authenticatedUser.id

# ビルド対象ブランチを取得
$targetBranch = $env:BUILD_SOURCEBRANCH

# プルリクエストの作成に POST を使用
$prUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId/pullrequests?api-version=6.0"

$body = @{
    sourceRefName = "refs/heads/$branchName"
    targetRefName = "$targetBranch"
    title = "Update package references to $packageName $packageVersion"
    description = "This PR was created automatically by the build pipeline."
    reviewers = @()
} | ConvertTo-Json

Write-Host "request $prUrl"
Write-Host "body $body"

$response = Invoke-RestMethod -Method Post -Uri $prUrl -Headers $headers -Body $body

Write-Host "response $response"

Write-Host "プルリクエストを作成しました。PR ID: $($response.pullRequestId)"

# プルリクエストの自動完了設定に PATCH を使用
$prUpdateUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId/pullrequests/$($response.pullRequestId)?api-version=6.0"

$prUpdateBody = @{
    autoCompleteSetBy = @{
        id = $buildServiceAccountId
    }
} | ConvertTo-Json

Invoke-RestMethod -Method Patch -Uri $prUpdateUrl -Headers $headers -Body $prUpdateBody

Write-Host "プルリクエストに自動完了設定を適用しました。"
