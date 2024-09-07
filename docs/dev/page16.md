# Azure DevOpsパイプラインでUbuntuエージェントを使用したバージョン更新の自動化（トリガー設定付き）

パイプライントリガーの追加
まず、パイプラインを特定のブランチ変更に応じて実行するために、トリガー設定を追加します。以下のYAMLファイルには、main ブランチの変更をトリガーにしてパイプラインが自動的に実行されるようになっています。

```yaml コードをコピーする
trigger:
  branches:
    include:
      - main  # mainブランチでの変更がトリガーされる

pr:
  branches:
    include:
      - feature/*  # featureブランチでのプルリクエストがトリガーされる
```

この設定により、main ブランチへのプッシュでパイプラインが自動的に実行されるほか、feature/* ブランチでプルリクエストが作成された場合にもパイプラインがトリガーされます。

全体のパイプライン設定
トリガー設定を加えたパイプライン全体の構成は以下のようになります。

``` yaml コードをコピーする
trigger:
  branches:
    include:
      - main  # mainブランチへの変更でパイプラインが実行

pr:
  branches:
    include:
      - feature/*  # featureブランチでのプルリクエストがトリガー

pool:
  vmImage: 'ubuntu-latest'  # Ubuntuエージェントを使用

variables:
  # バージョン管理のスキーマ: Major.Minor.Patch.Build
  major: 1
  minor: 0
  patch: 0
  build: $(Build.BuildId)

  version: '$(major).$(minor).$(patch).$(build)'

steps:
- task: UseDotNet@2
  inputs:
    packageType: 'sdk'
    version: '6.x'  # 使用する.NET SDKのバージョン

- task: NuGetToolInstaller@1

- task: NuGetCommand@2
  inputs:
    restoreSolution: '**/*.sln'

# パッケージのビルドとバージョン更新
- task: DotNetCoreCLI@2
  displayName: 'DLLプロジェクトのビルドとパック'
  inputs:
    command: 'pack'
    packagesToPack: '**/*.csproj'
    arguments: '--configuration Release /p:PackageVersion=$(version)'
    outputDir: '$(Build.ArtifactStagingDirectory)'

# パッケージのバージョン更新を確認
- task: Bash@3
  displayName: 'バージョン更新を確認'
  inputs:
    targetType: 'inline'
    script: |
      previous_version=$(cat version.txt || echo '0.0.0.0')
      if [ "$previous_version" != "$(version)" ]; then
        echo "バージョンが $previous_version から $(version) に更新されました"
        echo $(version) > version.txt
        echo "参照プロジェクトのビルドと更新を実行します..."

        # 更新されたパッケージを参照しているプロジェクトを見つけ、PackageReferenceを更新
        PACKAGE_NAME="MyUpdatedPackage"
        NEW_VERSION=$(cat version.txt)

        grep -rl "<PackageReference Include=\"$PACKAGE_NAME\"" ./ | grep .csproj | while read -r project; do
            echo "$project のPackageReferenceをバージョン $NEW_VERSION に更新します"
            
            # csprojファイル内のバージョン番号を更新
            sed -i "s|<PackageReference Include=\"$PACKAGE_NAME\" Version=\"[^\"]*\"|<PackageReference Include=\"$PACKAGE_NAME\" Version=\"$NEW_VERSION\"|" "$project"
            
            # バージョン更新後にプロジェクトをビルド
            echo "$project をビルド中"
            dotnet build "$project" --configuration Release
        done
      else
        echo "バージョンに変更はありません。"
      fi

# 自動コミット用の新しいブランチを作成
- script: |
    git checkout -b version-update-$(Build.BuildId)
    git config --global user.email "build@devops.com"
    git config --global user.name "Azure DevOps Pipeline"
    git add **/*.csproj
    git commit -m "パッケージバージョンを $(version) に更新"
    git push origin version-update-$(Build.BuildId)
  displayName: '変更を新しいブランチにコミット'

# バージョン更新のプルリクエストを自動作成
- task: AzureCLI@2
  inputs:
    azureSubscription: 'YourAzureSubscription'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az repos pr create --repository $(Build.Repository.Name) --source-branch version-update-$(Build.BuildId) --target-branch $(Build.SourceBranchName) --title "自動バージョン更新 $(version)" --description "パッケージ参照をバージョン $(version) に更新しました。" --auto-complete
  displayName: 'バージョン更新用のプルリクエストを作成'

# ビルド成果物の公開
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)'
    ArtifactName: 'drop'
    publishLocation: 'Container'
```

トリガー設定のポイント
## 1. trigger セクション
main ブランチへの変更をトリガーにして、パイプラインが自動的に実行されます。
これにより、重要なブランチに対して常に最新のバージョンが反映されるようになります。
## 2. pr セクション
feature/* ブランチでプルリクエストが作成された場合に自動的にパイプラインを実行します。これにより、機能ブランチでの変更も事前に確認でき、問題を未然に防ぐことができます。