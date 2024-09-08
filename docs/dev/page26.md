# Dapperを使用してストアドプロシージャを呼び出すアセンブリ、クラス名等の解析ツールをAzure DevOps Artifactsに登録し、CI/CDパイプラインで利用する方法
目次

はじめに
- Dapperを利用したストアドプロシージャ解析ツールの概要
- ツールをAzure DevOps Artifactsに登録する手順
- CI/CDパイプラインでArtifactsからツールを利用する手順
まとめ

## 1. はじめに
Dapperを使用してストアドプロシージャ（SP）を呼び出す際に、どのクラスやメソッドがどのSPを呼び出しているかを追跡することは重要です。今回は、Dapperのメソッドを解析してSP名、クラス名、メソッド名、タイムアウト値を抽出するRoslynベースの解析ツールを作成し、このツールをAzure DevOpsのArtifactsに登録して再利用可能な形で管理します。

さらに、このツールをCI/CDパイプライン内でArtifactsから呼び出し、結果をAzure DevOpsのWikiに自動的に投稿する方法についても説明します。

## 2. Dapperを利用したストアドプロシージャ解析ツールの概要
解析ツールは、以下の手順でDapperメソッドを解析します。

DapperのExecuteAsyncやQueryAsync、その他のメソッドを解析対象とする。
メソッド呼び出しから、クラス名、メソッド名、SP名、タイムアウト値を抽出する。
結果をMarkdown形式で出力し、プロジェクトごとのファイル名で保存する。

解析ツールの主要コード
```csharp コードをコピーする
// RoslynベースのDapper解析ツールの例（Program.cs）

var dapperMethods = new HashSet<string>
{
    "ExecuteAsync", "Execute", "QueryAsync", "Query", 
    "QueryFirstAsync", "QueryFirst", "QuerySingleAsync", 
    "QuerySingle", "QueryMultipleAsync", "QueryMultiple"
};

var storedProcedures = new List<(string ClassName, string MethodName, string SpName, string TimeoutValue)>();

foreach (var file in csFiles)
{
    var invocations = root.DescendantNodes().OfType<InvocationExpressionSyntax>();

    foreach (var invocation in invocations)
    {
        var memberAccess = invocation.Expression as MemberAccessExpressionSyntax;

        if (memberAccess != null && dapperMethods.Contains(memberAccess.Name.Identifier.Text))
        {
            // クラス名、メソッド名、SP名、タイムアウト値を取得
            // ...
        }
    }
}

// Markdown形式で結果を保存
using (var writer = new StreamWriter(outputFileName))
{
    writer.WriteLine($"# Stored Procedures used in {projectName}\n");
    writer.WriteLine("| Class Name | Method Name | Stored Procedure | Timeout |");
    foreach (var sp in storedProcedures)
    {
        writer.WriteLine($"| {sp.ClassName} | {sp.MethodName} | {sp.SpName} | {sp.TimeoutValue} |");
    }
}
```
## 3. ツールをAzure DevOps Artifactsに登録する手順
### 1. ビルドとArtifactsの作成
まず、解析ツールをビルドし、その成果物（バイナリ）をAzure DevOpsのArtifactsに登録します。

### 1.1 ツールのビルド
ビルド済みバイナリを作成します。

```bashコードをコピーする
dotnet publish -c Release -o out
```
これにより、outディレクトリに実行可能なバイナリが作成されます。

### 1.2 Azure DevOpsのArtifactsにバイナリを登録
Azure DevOps Pipeline内で、ビルド済みのバイナリをArtifactsに登録します。次のYAMLスクリプトは、バイナリを作成し、Artifactsとして保存する手順を示しています。

```yaml コードをコピーする
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: UseDotNet@2
  inputs:
    packageType: 'sdk'
    version: '7.x'

# ツールのビルド
- script: |
    dotnet publish path/to/StoredProcedureAnalyzer.csproj -c Release -o $(Build.ArtifactStagingDirectory)/StoredProcedureAnalyzer
  displayName: 'Build StoredProcedureAnalyzer'

# Artifactsに登録
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)/StoredProcedureAnalyzer'
    ArtifactName: 'StoredProcedureAnalyzer'
```
### 1.3 Artifactsへのアクセス
Artifactsに登録されたStoredProcedureAnalyzerは、他のパイプラインで再利用可能です。次のセクションで、これをCI/CDパイプラインでどのように使用するかを見ていきます。

## 4. CI/CDパイプラインでArtifactsからツールを利用する手順
### 2. Artifactsからツールをダウンロードし、実行
CI/CDパイプラインで、Artifactsからツールをダウンロードして実行し、その結果をMarkdownファイルに出力してWikiに投稿します。

### 2.1 Artifactsからツールをダウンロード
次のYAMLスクリプトでは、StoredProcedureAnalyzerをArtifactsからダウンロードして実行しています。

```yamlコードをコピーする
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  projectName: 'MyProject'
  wikiPath: '/Projects/$(projectName)/StoredProcedures'

steps:
# Artifactsからツールをダウンロード
- task: DownloadBuildArtifacts@0
  inputs:
    buildType: 'current'
    artifactName: 'StoredProcedureAnalyzer'

# 解析ツールを実行してMarkdownファイルを生成
- script: |
    ./StoredProcedureAnalyzer/StoredProcedureAnalyzer -- sourceCodeDirectory="path/to/your/service/code" --projectName=$(projectName)
  displayName: 'Run StoredProcedureAnalyzer'

# 生成されたMarkdownファイルをWikiに投稿
- script: |
    az devops configure --defaults organization=https://dev.azure.com/your-organization project=your-project
    az devops wiki page create --path $(wikiPath) --content @$(projectName)_stored_procedures.md --comment 'Updated stored procedures list for $(projectName)'
  displayName: 'Post Stored Procedures to Wiki'
  env:
    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)

# 生成されたMarkdownファイルをアーティファクトとして保存
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(projectName)_stored_procedures.md'
    ArtifactName: 'StoredProcedures'
```
### 2.2 ツールの実行と結果の確認

パイプラインが実行されると、ArtifactsからStoredProcedureAnalyzerツールがダウンロードされ、指定されたプロジェクトのソースコードを解析してストアドプロシージャの一覧をMarkdownファイルとして出力します。そのファイルは自動的にAzure DevOps Wikiに投稿されます。