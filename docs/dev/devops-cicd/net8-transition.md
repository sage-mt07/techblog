# 概要資料: .NET 6 から .NET 8 への移行とAzure DevOpsパイプラインの最適化

目次
1. [はじめに](#はじめに)
2. 現在のシステム構成
- 技術スタック
- Azure DevOpsパイプラインの設定
3. 現在の問題点
4. NET 8への移行
- 移行の理由
- .NET 8のメリット
5. 提案する解決策
- 全体のアプローチ
- readme.mdファイルの生成と配置
- Directory.Build.propsの活用
- 各プロジェクトのビルドパイプライン設定
6. この方式を採用するメリット
- 運用効率の向上
- セキュリティの強化
- スケーラビリティと保守性の向上
- Directory.Build.propsのメリット
- 導入コストメリット
7. 実装手順
- メインパイプラインの設定
    - readme.mdの生成スクリプト
    - readme.mdのコミットとプッシュ
    - Directory.Build.propsの設定
- 各プロジェクトのビルドパイプライン設定
8. ベストプラクティス
9. まとめ

## はじめに
本資料では、現在.NET 6で構築されているプロジェクトを.NET 8に移行し、Azure DevOpsパイプラインを最適化する方法について解説します。特に、各プロジェクトフォルダ内にreadme.mdファイルを配置し、これを通じてパッケージバージョンの管理とビルドの自動化を実現する手法を提案します。また、.NET 8で利用可能なDirectory.Build.propsの活用とそのメリットについても詳述します。

## 現在のシステム構成
### 技術スタック
フレームワーク: .NET 6
パッケージ管理: Azure DevOps Artifacts
CI/CDツール: Azure DevOps Pipelines
ソースコード管理: Azure Repos (Git)
### Azure DevOpsパイプラインの設定
メインパイプライン:
- パッケージの最新バージョンを取得し、Directory.Build.propsを更新。
- 更新内容をコミットし、プルリクエストを作成。
- 影響を受けるプロジェクトのビルドパイプラインをREST API経由でトリガー。

各プロジェクトのビルドパイプライン:
- 個別のプロジェクトフォルダ内の変更を検知してビルドを実行。

## 現在の問題点
1. パイプラインの複雑性:
メインパイプラインが複数のプロジェクトビルドパイプラインを手動でトリガーするスクリプトを必要とし、管理が煩雑。
2. セキュリティリスク:
パイプライン間の認証にPersonal Access Token (PAT) を使用しており、PATの管理やスコープ設定が煩雑。
3. 運用負荷の増大:
パイプラインの追加や変更時にスクリプトの調整が必要で、スケールが困難。
4. ビルドの一貫性:
パイプライン名の一意性を保つ必要があり、誤ったビルドパイプラインのトリガーリスクが存在。

## .NET 8への移行
移行の理由
- 最新の機能と性能向上:
  - .NET 8は、.NET 6に比べてパフォーマンスの改善や新機能が追加されています。
- サポート期間の延長:
  - 長期サポート（LTS）が提供され、セキュリティ更新やバグフィックスが継続的に提供されます。
- 開発者体験の向上:
  - 最新のツールやライブラリが利用可能で、開発効率が向上します。

### .NET 8のメリット
1. パフォーマンスの向上:
アプリケーションの実行速度やリソース効率が改善。
2. 新機能の追加:
最新のC#機能やライブラリのサポート。
3. セキュリティ強化:
最新のセキュリティパッチと改善が適用。
4. 開発効率の向上:
新しいツールや拡張機能の利用により、開発プロセスが効率化。
5. Directory.Build.propsの活用:
プロジェクト全体で共通の設定を一元管理でき、設定の一貫性と保守性が向上。

## 提案する解決策
### 全体のアプローチ
1. プロジェクトフォルダ内にreadme.mdを配置:
各プロジェクトフォルダにreadme.mdを配置し、使用しているパッケージの最新バージョンをリストアップ。
2. メインパイプラインでreadme.mdを生成・更新:
パッケージの最新バージョンを取得し、readme.mdを更新。
更新内容をコミットし、プルリクエストを作成。
3. Directory.Build.propsの活用:
.NET 8の機能として、Directory.Build.propsを使用してパッケージのバージョン管理を中央集約。
これにより、複数プロジェクト間で一貫したバージョン管理が可能。
4. 各プロジェクトのビルドパイプラインでパスフィルターを設定:
readme.mdやプロジェクトフォルダ内のファイルが更新された場合に自動的にビルドをトリガー。

### readme.mdファイルの生成と配置
目的: 各プロジェクトが使用しているNuGetパッケージの最新バージョンを一目で確認できるようにする。
配置場所: 各プロジェクトのcsprojファイルと同じディレクトリ。

### Directory.Build.propsの活用
Directory.Build.propsとは

Directory.Build.propsは、.NETプロジェクトのルートディレクトリに配置することで、プロジェクト全体に共通の設定を適用できるMSBuildプロパティファイルです。これにより、各プロジェクトのcsprojファイルに重複する設定を排除し、設定の一貫性と保守性を向上させることができます。

#### メリット

1. 中央集約された設定管理:
パッケージバージョン、共通のプロパティ、ターゲットフレームワークなどを一元管理できるため、各プロジェクトでの設定ミスや不整合を防止。
2. 設定の一貫性:
全プロジェクトで同一のバージョンや設定を共有することで、ビルドや実行時の一貫性が保たれる。
3. 保守性の向上:
設定を一箇所で変更するだけで、全プロジェクトに反映されるため、メンテナンスが容易。
4. コードの簡素化:
各csprojファイルから共通の設定を削除でき、プロジェクトファイルがシンプルになる。
5. パッケージ管理の効率化:
パッケージのバージョンをDirectory.Build.propsで一元管理することで、バージョンアップデートが容易。

具体的な設定例
```
<!-- File: Directory.Build.props -->
<Project>
  <ItemGroup>
    <!-- 共通のNuGetパッケージバージョンを定義 -->
    <PackageReference Update="Newtonsoft.Json" Version="13.0.1" />
    <PackageReference Update="Serilog" Version="2.10.0" />
    <!-- 必要に応じて他のパッケージも追加 -->
  </ItemGroup>
</Project>
```
使用方法

1. Directory.Build.propsの配置:
ソリューションのルートディレクトリにDirectory.Build.propsを配置します。
2. プロジェクトファイルの調整:
各プロジェクトのcsprojファイルから共通のパッケージバージョン設定を削除します。Directory.Build.propsで管理されるため、個別に設定する必要がなくなります。
3. メインパイプラインの更新:
Directory.Build.propsを更新するスクリプトをメインパイプラインに追加し、パッケージバージョンの一元管理を実現します。

### この方式を採用するメリット
運用効率の向上
- スクリプトの簡素化:
メインパイプラインから個別のビルドパイプラインをトリガーするスクリプトが不要となり、パイプライン管理が容易に。
- 自動化の強化:
パスフィルターによる自動トリガーにより、手動でのビルドトリガー作業が不要。
- セキュリティの強化
  - System.AccessTokenの活用:
    PATを使用せずにSystem.AccessTokenを利用することで、認証情報の管理リスクを低減。
  - 最小権限の原則:
System.AccessTokenのスコープを必要最低限に設定することで、セキュリティリスクを最小化。
- スケーラビリティと保守性の向上
  - プロジェクトの追加が容易:
新しいプロジェクトの追加時に、単にパスフィルターを設定するだけで対応可能。
  - パイプラインの一貫性:
共通のテンプレートやスクリプトを使用することで、パイプライン設定の一貫性を保ちやすくなる。

Directory.Build.propsのメリット
- 中央集約された設定管理:
全プロジェクトで共通の設定を一箇所で管理できるため、設定の一貫性と保守性が向上。
- 設定の一元化によるエラー削減:
各プロジェクトで個別に設定を管理する必要がなくなり、設定ミスや不整合を防止。
- バージョン管理の効率化:
パッケージバージョンをDirectory.Build.propsで一元管理することで、バージョンアップデートが迅速かつ確実に行える。
- プロジェクトファイルの簡素化:
各csprojファイルがシンプルになり、読みやすくメンテナンスが容易に。
- 新しいプロジェクトの迅速なセットアップ:
新規プロジェクト作成時にDirectory.Build.propsを参照するだけで、共通設定が自動的に適用されるため、セットアップ時間が短縮。

### 導入コストメリット
現在、パッケージの最新化は手動で行っており、パイプライン実行時には開発者が全体を制御する必要があります。この手動プロセスには以下のようなコストとリスクが伴います。

現状のコストとリスク
1. 人件費の増大:
開発者がパッケージの最新バージョンを手動で確認・更新する作業に時間を費やす必要があり、その分の人件費が発生します。
2. エラーの発生リスク:
手動作業によるヒューマンエラー（例: バージョンのミス、パッケージの漏れ）が発生しやすく、これがビルドの失敗や動作不良に繋がる可能性があります。
3. 一貫性の欠如:
手動更新では、プロジェクト間でのバージョン管理が一貫しない場合があり、依存関係の不整合が生じやすくなります。
4. 運用効率の低下:
パッケージの更新タイミングや方法が標準化されていないため、運用プロセスが非効率的になります。

提案する自動化方式のコストメリット
1. 人件費の削減:
パッケージの最新バージョン取得と更新を自動化することで、開発者が手動で行っていた作業を削減できます。これにより、開発者はより価値の高い業務に集中できます。
2. エラーの削減:
自動化により、パッケージバージョンのミスや漏れといったヒューマンエラーを大幅に減少させ、ビルドの安定性と信頼性を向上させます。
3. 一貫性と標準化の向上:
Directory.Build.propsと自動化スクリプトにより、全プロジェクトでのパッケージバージョン管理が一元化され、一貫性が保たれます。これにより、依存関係の不整合が防止されます。
4. 運用効率の向上:
パッケージの更新とビルドのトリガーが自動化されることで、運用プロセスが効率化され、迅速なリリースサイクルが実現します。
5. スケーラビリティの向上:
プロジェクト数が増加しても、自動化された仕組みにより、追加のプロジェクトを容易に管理・運用できるため、スケールに強いインフラを構築できます。
6. 保守コストの削減:
自動化されたパイプラインは、手動プロセスに比べて保守が容易であり、設定や更新が一元管理されているため、保守コストが削減されます。
7. 迅速な問題解決:
自動化により、パッケージの更新に関連する問題が早期に検出・解決されやすくなります。これにより、ダウンタイムやバグの発生を最小限に抑えられます。
8. 継続的改善の促進:
自動化されたプロセスは、継続的な改善が容易であり、フィードバックループを迅速に取り入れることができます。これにより、運用プロセスの最適化が進みます。

投資対効果 (ROI) の概要
初期の自動化システムの導入には一定のコストがかかりますが、以下のような長期的な利益が期待できます。

- 初期投資:
スクリプト開発、パイプライン設定、テストおよびデプロイのための開発者時間。
必要に応じて、追加のツールやライセンスの取得。
- 長期的な利益:
人件費の削減によるコスト節約。
エラー削減による修正コストの低減。
運用効率の向上による生産性の向上。
スケーラビリティの向上による将来的な拡張性の確保。
保守コストの削減。

これらを総合的に考慮すると、自動化による初期投資は長期的に見て十分に回収可能であり、さらには企業全体の生産性と品質向上に寄与します。

## 実装手順
メインパイプラインの設定
readme.mdの生成スクリプト
スクリプト: script/GenerateReadme.ps1
```
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

    # readme.mdの内容を生成
    $readmeContent = @"
# Package Versions for $(($csproj.BaseName))

| Package | Current Version | Latest Version |
|---------|------------------|----------------|
"@

    foreach ($pkg in $packageList) {
        $readmeContent += "| $($pkg.Package) | $($pkg.CurrentVersion) | $($pkg.LatestVersion) |\n"
    }

    # readme.mdに書き出す
    $readmePath = Join-Path -Path $ProjectDirectory -ChildPath "readme.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8

    Write-Host "Generated readme.md at $readmePath"
}

```
ポイント:
- 各プロジェクトフォルダ内の.csprojファイルを検索し、PackageReferenceを抽出。
- nuget CLIを使用して各パッケージの最新バージョンを取得。
- テーブル形式でreadme.mdを生成し、プロジェクトフォルダに配置。

注意点:
- nuget CLIがエージェントにインストールされていることを確認。
- パッケージソースURLを必要に応じて変更（ここではnuget.orgを使用）。

readme.mdのコミットとプッシュ
スクリプト: script/CommitReadme.ps1

```
# File: script/CommitReadme.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$ProjectDirectory,

    [Parameter(Mandatory = $true)]
    [string]$BranchName
)

# Git設定
git config user.email "build@yourdomain.com"
git config user.name "Build Agent"

# 変更があるか確認
$hasChanges = git status --porcelain

if ($hasChanges) {
    # 変更を追加
    git add "$ProjectDirectory/readme.md"

    # コミット
    git commit -m "Update readme.md with latest package versions for $(Split-Path -Leaf $ProjectDirectory)"

    # 新しいブランチを作成してプッシュ
    git checkout -b "$BranchName"
    git push origin "$BranchName"
} else {
    Write-Host "No changes detected in readme.md for $ProjectDirectory."
}

```
ポイント:

- readme.mdに変更があればコミットし、新しいブランチを作成してプッシュ。
- BranchNameにはユニークなブランチ名を設定（例: update-readme-refs-12345）。

Directory.Build.propsの設定
スクリプト: script/UpdateDirectoryBuildProps.ps1

```
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
```

ポイント:
- LatestPackagesCsvPathで指定されたCSVファイルからパッケージ情報を読み込み。
- Directory.Build.propsを更新し、共通のパッケージバージョンを一元管理。
- 既存のPackageReferenceをクリアし、新しいバージョンで再設定。

注意点:
- Directory.Build.propsの既存設定との整合性を確認。
- XML操作を行うため、スクリプトの信頼性を確保。

## 各プロジェクトのビルドパイプライン設定

パスフィルターの設定
Azure DevOpsのビルドパイプラインには、パスフィルターを設定して特定のファイルやフォルダに変更があった場合のみビルドをトリガーするように設定できます。

設定手順:
1. ビルドパイプラインの編集画面に移動します。
1. 「Triggers」タブを選択します。
1. **「Continuous integration」**を有効にします。
1. パスフィルターを以下のように設定します。
```
Include:
  - source/ProjectDirectoryX/**
  - source/ProjectDirectoryX/readme.md
  - Directory.Build.props
```
例:

Project1 Build Pipeline
```
Include:
  - source/ProjectDirectory1/**
  - source/ProjectDirectory1/readme.md
  - Directory.Build.props

```

ビルドパイプラインのYAML設定例
例: azure-pipelines-project1.yml
```
# File: azure-pipelines-project1.yml

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - source/ProjectDirectory1/**
      - source/ProjectDirectory1/readme.md
      - Directory.Build.props

pool:
  vmImage: 'windows-latest'

steps:
- task: UseDotNet@2
  inputs:
    packageType: 'sdk'
    version: '8.x.x' # 必要な.NET SDKバージョンに変更
    installationPath: $(Agent.ToolsDirectory)/dotnet

- script: dotnet build source/ProjectDirectory1/Project1.csproj --configuration Release
  displayName: 'Build Project1'

```
ポイント:

- triggerセクションでパスフィルターを設定。
- プロジェクトフォルダ内のファイルやDirectory.Build.propsに変更があった場合のみビルドを実行。
- ビルドステップには、必要なビルドタスクを定義（例: .NET SDKのインストール、プロジェクトのビルド）。

## セキュリティと認証の考慮事項
a. System.AccessToken の活用
Azure DevOpsでは、System.AccessTokenを使用してREST APIにアクセスすることで、PAT（Personal Access Token）を使用せずに認証を行うことが可能です。これにより、セキュリティが向上し、運用負荷が低減されます。

設定方法:

YAMLパイプラインのチェックアウトステップでpersistCredentialsをtrueに設定します。これにより、後続のGit操作やREST API呼び出しで認証情報が保持されます。

```yamlコードをコピーする
- checkout: self
  persistCredentials: true
```  
スクリプト内でSystem.AccessTokenを使用:

System.AccessTokenは自動的に環境変数として利用可能です。
スクリプト内でこのトークンを使用してREST APIに認証ヘッダーを設定します。
例:
```
powershellコードをコピーする
$accessToken = $env:SYSTEM_ACCESSTOKEN
$headers = @{
    Authorization = "Bearer $accessToken"
}
```

注意点:

1. OAuthトークンへのアクセス許可:
YAMLパイプラインでは、persistCredentials: trueを設定する必要があります。
Classic Editorの場合は、「Allow scripts to access the OAuth token」オプションを有効にします。
1. トークンのセキュリティ:
System.AccessTokenはパイプラインの実行時にのみ有効です。
スクリプト内でトークンを直接出力しないように注意してください。
1. 最小権限の原則
System.AccessTokenに付与される権限は、必要最低限に抑えることが推奨されます。具体的には、以下のような権限設定を行います。

プロジェクト設定に移動します。
**「Permissions」**タブで、パイプラインに関連する権限を確認・設定します。
「Build Service」アカウントに対して、必要な権限（例: リポジトリの読み書き、プルリクエストの作成）を付与します。

## ベストプラクティス
1. パイプライン名の一意性:
各ビルドパイプライン名を一意に設定し、パスフィルターによるトリガーが正確に動作するようにします。
1. スクリプトの再利用性とモジュール化:
共通の処理を関数化し、複数プロジェクトで再利用可能にします。
1. エラーハンドリングの強化:
スクリプト内で発生するエラーを適切にハンドリングし、ログに詳細なメッセージを出力します。
1. 詳細なログ出力:
各ステップやスクリプト内で重要な情報やエラーメッセージをログに出力し、トラブルシューティングを容易にします。
1. 知の設定:
パイプラインの成功や失敗時にチームメンバーに通知を送信し、迅速な対応を可能にします。
1. ドキュメントの整備:
パイプラインの設定方法やスクリプトの使用方法について、適切なドキュメントを作成し、チーム内で共有します。

## まとめ

### 現在の問題点と.NET 8への移行による改善

問題点:
- パイプラインの複雑性、セキュリティリスク、運用負荷、ビルドの一貫性の欠如。
改善点:
- .NET 8への移行により、最新機能とパフォーマンス向上を享受。
- readme.mdを通じたパッケージバージョン管理とパスフィルターを活用したビルド自動化により、運用効率とセキュリティを強化。
- 各プロジェクトのビルドパイプラインが独立して動作することで、スケーラビリティと保守性を向上。
この方式を採用するメリット
- 運用効率の向上:
スクリプトの簡素化と自動化により、手動作業が削減されます。
- セキュリティの強化:
System.AccessTokenの活用により、PATの管理リスクが低減されます。
- スケーラビリティと保守性の向上:
パスフィルターを活用することで、新しいプロジェクトの追加が容易になり、ビルドパイプラインの管理が簡素化されます。
- ビルドの一貫性:
パッケージバージョン管理が中央集約化され、依存関係の問題が減少します。
