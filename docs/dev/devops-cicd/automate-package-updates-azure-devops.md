# Azure DevOps Classic Editorでの`.nupkg`ファイルからパッケージ情報を取得し、自動プルリクエストを作成する方法

Azure DevOpsを活用したCI/CDパイプラインの自動化は、開発プロセスの効率化に欠かせません。特に、NuGetパッケージの管理やバージョン更新を自動化することで、手動でのミスを減らし、迅速なデプロイを実現できます。本記事では、**Azure DevOpsのClassic Editor**を使用し、既存の`.nupkg`ファイルからパッケージ名とバージョンを取得し、他のプロジェクトファイルを更新、さらに自動的にプルリクエストを作成するPowerShellスクリプトを紹介します。このスクリプトは、対象のソリューションが同じリポジトリに含まれている前提で設計されています。

## 目次

1. [はじめに](#はじめに)
2. [必要な前提条件](#必要な前提条件)
3. [パイプライン変数の設定](#パイプライン変数の設定)
4. [PowerShellモジュールの作成](#powershellモジュールの作成)
5. [PowerShellスクリプトの作成](#powershellスクリプトの作成)
6. [パイプラインタスクの設定](#パイプラインタスクの設定)
7. [ベストプラクティス](#ベストプラクティス)
8. [まとめ](#まとめ)

## はじめに

Azure DevOpsのClassic Editorを利用して、既存の`.nupkg`ファイルからパッケージ名とバージョンを自動的に取得し、プロジェクトファイルを更新、さらにその変更をプルリクエストとして自動作成することで、継続的なデリバリーを効率化します。これにより、パッケージの更新作業を手動で行う手間を省き、エラーのリスクを減少させることができます。

## 必要な前提条件

- **Azure DevOpsアカウント**: プロジェクト管理とパイプライン設定が可能なアカウント。
- **PowerShell**: スクリプト実行に使用。
- **nuget.exe**: NuGetパッケージの作成に使用。
- **Git**: リポジトリ管理とプルリクエスト作成に使用。
- **適切な権限**: パイプラインがリポジトリやプロジェクト設定にアクセスできる権限。

## パイプライン変数の設定

Azure DevOpsの組み込み変数を活用し、パイプライン内で必要な情報を動的に取得します。特に以下の変数を使用します：

| 目的                     | 組み込み変数                   | 説明                                                                                           |
|--------------------------|-------------------------------|------------------------------------------------------------------------------------------------|
| 組織名 (`$organization`) | `System.TeamFoundationCollectionUri` | Azure DevOpsのコレクションURI。例: `https://dev.azure.com/myOrg/`から`myOrg`を抽出します。 |
| プロジェクト名 (`$project`)      | `System.TeamProject`         | 現在のプロジェクトの名前。                                                               |
| リポジトリID (`$repositoryId`)    | `Build.Repository.ID`        | 現在のビルドに関連付けられているリポジトリのGUID。                                        |
| ビルド対象ブランチ (`$targetBranch`) | `Build.SourceBranch`        | プルリクエストのターゲットとなるブランチ名。例: `refs/heads/main`、`refs/heads/develop`など。 |

### 組織名の抽出

`System.TeamFoundationCollectionUri`から組織名を抽出するには、PowerShellの正規表現を使用します。

```powershell
# System.TeamFoundationCollectionUri の例: https://dev.azure.com/myOrg/
$collectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI

if ($collectionUri -match "https://dev\.azure\.com/(?<organization>[^/]+)/") {
    $organization = $matches['organization']
} else {
    Write-Error "組織名を URI から抽出できませんでした。"
    exit 1
}
```
## PowerShellモジュールの作成

再利用可能な関数を含むPowerShellモジュールを作成し、パイプライン内で簡単に呼び出せるようにします。ここでは、`.nupkg`ファイルからパッケージ名とバージョンを取得する関数を定義します。

### `PackageUtils.psm1` の作成

1. **ディレクトリ構造の準備**:
   プロジェクトリポジトリ内に `Scripts` フォルダを作成し、その中に `PackageUtils.psm1` ファイルを配置します。

2. **関数の定義**:
   以下の内容で `PackageUtils.psm1` を作成します。

   ```powershell
   # File: Scripts/PackageUtils.psm1
   
   function Get-PackageInfoFromNupkg {
       param (
           [Parameter(Mandatory = $true)]
           [string]$NupkgPath
       )
   
       if (-not (Test-Path $NupkgPath)) {
           Write-Error "指定された .nupkg ファイルが存在しません: $NupkgPath"
           return $null
       }
   
       # 一時ディレクトリを作成
       $tempDir = New-TemporaryFile | Remove-Item -Force -Confirm:$false -ErrorAction SilentlyContinue
       $tempDir = Split-Path $tempDir
       New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
   
       try {
           # .nupkgファイルを解凍
           Expand-Archive -Path $NupkgPath -DestinationPath $tempDir -Force
   
           # 解凍先から .nuspec ファイルを検索
           $nuspecFile = Get-ChildItem -Path $tempDir -Recurse -Filter *.nuspec | Select-Object -First 1
   
           if ($null -eq $nuspecFile) {
               Write-Error ".nupkg ファイル内に .nuspec ファイルが見つかりませんでした。"
               return $null
           }
   
           # .nuspecファイルをXMLとして読み込む
           [xml]$nuspecContent = Get-Content $nuspecFile.FullName
   
           # パッケージ名とバージョンを取得
           $packageName = $nuspecContent.package.metadata.id
           $packageVersion = $nuspecContent.package.metadata.version
   
           return @{ Name = $packageName; Version = $packageVersion }
       }
       finally {
           # 一時ディレクトリを削除
           Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
       }
   }
   ```
   ## PowerShellスクリプトの作成

次に、PowerShellスクリプトを作成します。このスクリプトは、対象ソリューションが同じリポジトリに存在することを前提とし、必要なパラメータをパイプラインから受け取ります。**ビルド対象ブランチ (`$targetBranch`)** は、事前定義済みのビルド変数 `Build.SourceBranch` を使用して汎用性を高めます。

### `UpdatePackageReferences.ps1` の作成

プロジェクトリポジトリ内に `Scripts` フォルダを作成し、その中に `UpdatePackageReferences.ps1` ファイルを配置します。

```powershell
# File: Scripts/UpdatePackageReferences.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

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

# === 2. .nupkg ファイルの取得 ===

# 生成された .nupkg ファイルを取得
$latestNupkg = Get-ChildItem -Path $PackageOutputDir -Filter *.nupkg | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $latestNupkg) {
    Write-Error ".nupkg ファイルが生成されていません。nuget pack が成功したか確認してください。"
    exit 1
}

Write-Host "最新の .nupkg ファイル: $($latestNupkg.FullName)"

# === 3. PowerShellモジュールのインポート ===

# モジュールのパス（スクリプトと同じディレクトリに配置）
$modulePath = "$PSScriptRoot\PackageUtils.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Error "モジュールファイルが見つかりません: $modulePath"
    exit 1
}

Import-Module $modulePath

# === 4. パッケージ情報の取得 ===

$packageInfo = Get-PackageInfoFromNupkg -NupkgPath $latestNupkg.FullName

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
$csprojFiles = Get-ChildItem -Path . -Recurse -Filter *.csproj | Where-Object { $_.FullName -ne (Resolve-Path $ProjectPath) }

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

# === 6. ビルドの実行 ===

dotnet build $SolutionPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "ビルドに失敗しました。プルリクエストの作成を中止します。"
    exit 1
}

# === 7. Git の設定とコミット ===

git config user.email "build@yourdomain.com"
git config user.name "Build Agent"

# 新しいブランチの作成と変更のコミット
$branchName = "pullrequests/update-package-version-$(Build.BuildId)"
git checkout -b $branchName
git add **/*.csproj
git commit -m "Update package references to $packageName $packageVersion"

# === 8. 変更のプッシュ ===
git push origin $branchName

# === 9. プルリクエストの作成 ===
## 環境変数から System.AccessToken を取得
$accessToken = $env:SYSTEM_ACCESSTOKEN

## 認証ヘッダーの作成（Bearer 認証を使用）
$headers = @{
    Authorization = "Bearer $accessToken"
    Content-Type = "application/json"
}
## ビルドサービスアカウントの ID を取得$profileUrl = "https://vssps.dev.azure.com/$organization/_apis/connectionData?connectOptions=none&lastChangeId=-1&lastChangeId64=-1"
$profileResponse = Invoke-RestMethod -Method Get -Uri $profileUrl -Headers $headers
$buildServiceAccountId = $profileResponse.authenticatedUser.id

## ビルド対象ブランチを取得
$targetBranch = $env:BUILD_SOURCEBRANCH

## プルリクエストの作成に POST を使用
$prUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId/pullrequests?api-version=6.0"

$body = @{
    sourceRefName = "refs/heads/$branchName"
    targetRefName = "$targetBranch"
    title = "Update package references to $packageName $packageVersion"
    description = "This PR was created automatically by the build pipeline."
    reviewers = @()
} | ConvertTo-Json

$response = Invoke-RestMethod -Method Post -Uri $prUrl -Headers $headers -Body $body

Write-Host "プルリクエストを作成しました。PR ID: $($response.pullRequestId)"

## プルリクエストの自動完了設定に PATCH を使用
$prUpdateUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId/pullrequests/$($response.pullRequestId)?api-version=6.0"

$prUpdateBody = @{
    autoCompleteSetBy = @{
        id = $buildServiceAccountId
    }
} | ConvertTo-Json

Invoke-RestMethod -Method Patch -Uri $prUpdateUrl -Headers $headers -Body $prUpdateBody

Write-Host "プルリクエストに自動完了設定を適用しました。"
```

変更点:
```
$body = @{
    sourceRefName = "refs/heads/$branchName"
    targetRefName = "$targetBranch" # 変更前: "refs/heads/main"
    title = "Update package references to $packageName $packageVersion"
    description = "This PR was created automatically by the build pipeline."
    reviewers = @()
} | ConvertTo-Json

```

targetRefName の動的設定: プルリクエストのターゲットブランチを固定の "refs/heads/main" から、ビルド変数 Build.SourceBranch を使用して動的に設定するように変更しました。これにより、ビルド対象ブランチに応じてプルリクエストのターゲットブランチが自動的に設定され、スクリプトの汎用性が向上します。


## パイプラインタスクの設定

Azure DevOpsのClassic Editorを使用して、パイプラインに必要なタスクを追加します。以下の手順で設定を行います。

### 1. パイプラインの編集を開始

1. **Azure DevOpsにサインイン**:
   [Azure DevOps](https://dev.azure.com/)にアクセスし、対象のプロジェクトに移動します。

2. **パイプラインに移動**:
   左側のナビゲーションバーから「**Pipelines（パイプライン）**」を選択し、編集したいクラシックパイプラインを選びます。

3. **パイプラインの編集**:
   該当パイプラインの右側にある「**Edit（編集）**」ボタンをクリックします。

### 2. 変数の設定

1. **変数タブを開く**:
   パイプライン編集画面の上部にある「**Variables（変数）**」タブをクリックします。

2. **変数の追加**:
   以下の変数を追加します。必要に応じて「**Keep this value secret（この値を秘密にする）**」を有効にします。

   | 変数名          | 値                                      | 説明                                     |
   |-----------------|-----------------------------------------|------------------------------------------|
   | `ORGANIZATION`  | `your_organization`                     | Azure DevOpsの組織名（例: `myOrg`）        |
   | `PROJECT`       | `your_project`                          | Azure DevOpsのプロジェクト名（例: `myProject`） |
   | `REPOSITORY_ID` | `your_repository_id`                    | リポジトリのID（後述の取得方法を参照）     |
   | `TARGET_BRANCH` | `refs/heads/main` または `refs/heads/develop` など | プルリクエストのターゲットブランチ名      |

### 3. エージェントジョブの設定変更

1. **ジョブの詳細設定**:
   パイプライン編集画面で、ジョブ名（例: **Agent job 1**）をクリックして詳細設定を表示します。

2. **OAuthトークンへのアクセス許可**:
   「**Additional options（追加オプション）**」セクション内にある「**Allow scripts to access the OAuth token**」チェックボックスをオンにします。

   ![Allow scripts to access the OAuth token](https://learn.microsoft.com/ja-jp/azure/devops/pipelines/repos/github/media/connect-to-github/allow-scripts-to-access-the-oauth-token.png?view=azure-devops)

   これにより、スクリプト内で `System.AccessToken` を利用してAzure DevOpsのREST APIやGit操作を認証できるようになります。

### 4. PowerShellタスクの追加

1. **PowerShellタスクの追加**:
   ジョブ内で「**+**」ボタンをクリックし、「**PowerShell**」タスクを選択して追加します。

2. **PowerShellスクリプトの設定**:
   - **タイプ**: `File Path` を選択。
   - **スクリプトファイル**: `Scripts\UpdatePackageReferences.ps1` を指定。
   - **Arguments**: 以下のようにパラメータを渡します。
     ```plaintext
     -ProjectPath "Path\To\Your\Project.csproj" -SolutionPath "Path\To\Your\Solution.sln" -PackageOutputDir "Output\Packages"
     ```
     ここで、`Path\To\Your\Project.csproj` および `Path\To\Your\Solution.sln` は実際のプロジェクトとソリューションのパスに置き換えてください。

   - **オプション設定**:
     - 「**Options（オプション）**」タブで「**Allow scripts to access the OAuth token**」が有効になっていることを確認します。

   ![PowerShell Task Settings](https://learn.microsoft.com/ja-jp/azure/devops/pipelines/tasks/media/utility/powershell/powershell-task-settings.png)

3. **保存と実行**:
   - 「**Save**」をクリックしてパイプラインを保存。
   - 必要に応じて「**Run**」ボタンをクリックしてパイプラインを実行し、動作を確認します。

### 5. ビルド変数の削減と汎用性の向上

パイプライン内で事前定義済みのビルド変数 `Build.SourceBranch` を使用することで、パラメータの数を減らし、スクリプトの汎用性を向上させます。これにより、異なるブランチでも同じスクリプトを再利用できるようになります。

#### スクリプト内での使用例

`UpdatePackageReferences.ps1` スクリプト内で、パイプライン変数 `Build.SourceBranch` を使用してターゲットブランチを動的に設定します。

```powershell
# ビルド対象ブランチを取得
$targetBranch = $env:BUILD_SOURCEBRANCH
```
これにより、スクリプトがどのブランチからビルドされたかに応じて、自動的にプルリクエストのターゲットブランチが設定されます。

6. 変数グループの活用（オプション）
複数のパイプラインで共通の変数を使用する場合、変数グループを作成して一元管理することをお勧めします。これにより、メンテナンスが容易になり、一貫性を保つことができます。

変数グループの作成:

「Pipelines」 > 「Library」に移動します。
「+ Variable group」をクリックし、グループ名（例: CommonSettings）を入力します。
必要な変数（ORGANIZATION、PROJECT、REPOSITORY_ID、TARGET_BRANCH など）を追加します。
「Save」をクリックして保存します。
パイプラインへの変数グループのリンク:

パイプライン編集画面で「Variables（変数）」タブを選択します。
「Link variable group」をクリックし、作成した変数グループを選択します。

7. エージェントジョブの並列実行設定（オプション）
必要に応じて、複数のジョブを並列で実行する設定を行うことで、ビルド時間を短縮できます。ただし、依存関係があるタスクがある場合は注意が必要です。

スクリプトの詳細解説
1. 組織名、プロジェクト名、リポジトリIDの取得
Azure DevOpsの組み込み変数を使用して、必要な情報を動的に取得します。

組織名 ($organization): System.TeamFoundationCollectionUri から正規表現を使用して抽出。

プロジェクト名 ($project): System.TeamProject から取得。

リポジトリID ($repositoryId): Build.Repository.ID から取得。

2. .nupkg ファイルの取得
パイプラインが生成した.nupkgファイルを取得します。これにより、最新のパッケージ情報を基にプロジェクトファイルを更新できます。
```
# 生成された .nupkg ファイルを取得
$latestNupkg = Get-ChildItem -Path $PackageOutputDir -Filter *.nupkg | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $latestNupkg) {
    Write-Error ".nupkg ファイルが生成されていません。nuget pack が成功したか確認してください。"
    exit 1
}

Write-Host "最新の .nupkg ファイル: $($latestNupkg.FullName)"

```
3. PowerShellモジュールのインポート
事前に作成したPackageUtils.psm1モジュールをインポートし、再利用可能な関数を利用します。
```
# モジュールのパス（スクリプトと同じディレクトリに配置）
$modulePath = "$PSScriptRoot\PackageUtils.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Error "モジュールファイルが見つかりません: $modulePath"
    exit 1
}

Import-Module $modulePath

```
4. パッケージ情報の取得
.nupkgファイルからパッケージ名とバージョンを取得します。
```
# パッケージ情報の取得
$packageInfo = Get-PackageInfoFromNupkg -NupkgPath $latestNupkg.FullName

if ($null -eq $packageInfo) {
    Write-Error "パッケージ情報の取得に失敗しました。"
    exit 1
}

$packageName = $packageInfo.Name
$packageVersion = $packageInfo.Version

Write-Host "パッケージ名: $packageName"
Write-Host "パッケージバージョン: $packageVersion"
```

5. 他の .csproj ファイルの更新
取得したパッケージ名とバージョンを使用して、他のプロジェクトファイルのPackageReferenceを更新します。

```
# 更新対象の .csproj ファイルを取得（自分自身のプロジェクトを除外）
$csprojFiles = Get-ChildItem -Path . -Recurse -Filter *.csproj | Where-Object { $_.FullName -ne (Resolve-Path $ProjectPath) }

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
```

6. ビルドの実行
更新後のソリューションをビルドし、ビルドに失敗した場合はパイプラインを中断します。
```
dotnet build $SolutionPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "ビルドに失敗しました。プルリクエストの作成を中止します。"
    exit 1
}
```

7. Git の設定とコミット
Gitユーザー情報を設定し、新しいブランチを作成して変更をコミット・プッシュします。
```
git config user.email "build@yourdomain.com"
git config user.name "Build Agent"

# 新しいブランチの作成と変更のコミット
$branchName = "pullrequests/update-package-version-$(Build.BuildId)"
git checkout -b $branchName
git add **/*.csproj
git commit -m "Update package references to $packageName $packageVersion"
```
変更点:
```
$branchName = "pullrequests/update-package-version-$(Build.BuildId)"
```
上記の行では、ブランチ名にpullrequests/というプレフィックスを追加し、ブランチ名をpullrequests/update-package-version-123のように設定しています。これにより、ブランチがプルリクエスト用であることが明確になります。

8. 変更のプッシュ
作成したブランチをリモートリポジトリにプッシュします。
```
git push origin $branchName
```

9. プルリクエストの作成
Azure DevOpsのREST APIを使用してプルリクエストを作成し、自動完了設定を適用します。ビルド対象ブランチ ($targetBranch) は、事前定義済みのビルド変数 Build.SourceBranch を使用して設定します。
```
# 環境変数から System.AccessToken を取得
$accessToken = $env:SYSTEM_ACCESSTOKEN

# 認証ヘッダーの作成（Bearer 認証を使用）
$headers = @{
    Authorization = "Bearer $accessToken"
    Content-Type = "application/json"
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

$response = Invoke-RestMethod -Method Post -Uri $prUrl -Headers $headers -Body $body

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
```

変更点:
```
# ビルド対象ブランチを取得
$targetBranch = $env:BUILD_SOURCEBRANCH

$body = @{
    sourceRefName = "refs/heads/$branchName"
    targetRefName = "$targetBranch" # 変更前: "refs/heads/main"
    title = "Update package references to $packageName $packageVersion"
    description = "This PR was created automatically by the build pipeline."
    reviewers = @()
} | ConvertTo-Json
```

targetRefName の動的設定: プルリクエストのターゲットブランチを事前定義済みのビルド変数 Build.SourceBranch を使用して設定するように変更しました。これにより、ビルド対象ブランチに応じてプルリクエストのターゲットブランチが自動的に設定され、スクリプトの汎用性が向上します。
ベストプラクティス
1. モジュール化と再利用性
PowerShellモジュールを作成し、共通の処理を関数として定義することで、複数のパイプラインでの再利用性を高めます。例えば、Get-PackageInfoFromNupkg 関数をモジュール化することで、他のスクリプトでも簡単に利用できます。

2. セキュリティの確保
System.AccessTokenの取り扱い: System.AccessToken は強力な権限を持つため、スクリプト内でこのトークンがログや出力に表示されないよう注意してください。例えば、Write-Host $accessToken のような出力を避ける。

最小権限の原則: パイプラインが必要とする最小限の権限を付与します。System.AccessToken の権限は、プロジェクトの設定で適切に制限してください。

3. エラーハンドリング
各ステップでエラーチェックを行い、問題が発生した場合にパイプラインを中断するようにします。これにより、後続の処理に不整合が生じるのを防ぎます。
```
if ($null -eq $packageInfo) {
    Write-Error "パッケージ情報の取得に失敗しました。"
    exit 1
}

```
4. 変数グループの活用
複数のパイプラインで共通の変数を使用する場合、変数グループを作成して一元管理します。これにより、メンテナンスが容易になります。

変数グループの作成:

「Pipelines」 > 「Library」に移動します。
「+ Variable group」をクリックし、グループ名（例: CommonSettings）を入力します。
必要な変数（ORGANIZATION、PROJECT、REPOSITORY_ID、TARGET_BRANCH など）を追加します。
「Save」をクリックして保存します。
パイプラインへの変数グループのリンク:

パイプライン編集画面で「Variables（変数）」タブを選択します。
「Link variable group」をクリックし、作成した変数グループを選択します。
5. ロギングと通知
重要なステップやエラー発生時に詳細なログを出力し、必要に応じて通知を設定します。これにより、問題の早期発見と対応が可能になります。

```
Write-Host "プルリクエストを作成しました。PR ID: $($response.pullRequestId)"
```

## まとめ
Azure DevOpsのClassic Editorを使用して、既存の.nupkgファイルからパッケージ名とバージョンを自動的に取得し、プロジェクトファイルを更新、さらに自動的にプルリクエストを作成する一連のプロセスを構築する方法を解説しました。これにより、パッケージの更新作業を自動化し、手動でのミスを減少させるとともに、開発プロセスの効率化を図ることができます。

### 主要なポイント
再利用可能なスクリプトとモジュールの作成: PowerShellモジュールを作成し、共通の処理を関数として定義することで、複数のパイプラインでの再利用性を高めます。

Azure DevOpsの組み込み変数の活用: 組織名、プロジェクト名、リポジトリID、ターゲットブランチなどの情報は、Azure DevOpsの組み込み変数を活用して動的に取得します。

セキュリティとエラーハンドリングの徹底: System.AccessToken の取り扱いに注意し、エラーチェックを行って信頼性を確保します。

変数グループによる一元管理: 複数のパイプラインで共通の変数を使用する場合、変数グループを作成して一元管理します。
