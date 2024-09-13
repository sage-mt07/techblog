# Azure DevOps パイプラインで Docker イメージの最新タグを自動設定する方法

Azure DevOps パイプラインを使用して、Azure App Service にコンテナベースのアプリケーションをデプロイする際、Docker イメージのタグを常に最新に保つ方法について紹介します。

特に、以下の YAML コードの DockerImageTag を常に最新のタグに自動的に更新する方法を解説します。

```yaml コードをコピーする
steps:
- task: AzureRmWebAppDeployment@4
  displayName: 'Azure App Service Deploy: ap012'
  inputs:
    azureSubscription: '********-****-****-****-************'
    appType: webAppContainer
    WebAppName: ap012
    DockerNamespace: linuxappreg.azurecr.io
    DockerRepository: azuretest01
    DockerImageTag: 100
```

この設定では、DockerImageTag に固定値が設定されており、常に同じタグのイメージがデプロイされます。これを、最新のタグを自動的に使用する方法に変更する方法を見ていきます。

## 方法 1: ビルド番号を使用して最新のタグを自動設定する
まず、もっとも簡単な方法は、パイプラインのビルド番号を DockerImageTag として使用することです。これにより、ビルドが行われるたびに一意のタグを生成し、それを使用してイメージのバージョンを自動的に更新できます。

手順
DockerImageTag にビルドIDを指定します。Azure DevOps では、$(Build.BuildId) を使用することで、各ビルドごとに一意の ID が生成されます。
これを DockerImageTag に適用するだけで、常に最新のビルド番号が使用されるようになります。
修正後のコード
```yaml コードをコピーする
steps:
- task: AzureRmWebAppDeployment@4
  displayName: 'Azure App Service Deploy: ap012'
  inputs:
    azureSubscription: '********-****-****-****-************'  # サブスクリプションIDを伏字にしています
    appType: webAppContainer
    WebAppName: ap012
    DockerNamespace: linuxappreg.azurecr.io
    DockerRepository: azuretest01
    DockerImageTag: $(Build.BuildId)  # ビルドIDをタグとして使用
```

利点
簡単に導入でき、すぐに効果を確認できます。
各ビルドごとに新しいタグが付与されるため、タグの競合や誤ったデプロイを防ぐことができます。

## 方法 2: Docker レジストリから最新タグを取得して設定する

次に、もう少し高度な方法として、Docker レジストリから最新のタグを取得し、それを DockerImageTag として使用する方法です。これは、特定のルールに従ってバージョニングされたタグ（例: latest や v1.0.0）を常に最新に保ちたい場合に有効です。

手順
Azure CLI を使用して、Azure Container Registry (ACR) から最新のタグを取得します。
取得したタグを Azure DevOps パイプラインの変数として設定します。
この変数を DockerImageTag に適用し、常に最新のイメージをデプロイします。
修正後のコード
```yaml
コードをコピーする
steps:
- script: |
    echo "Getting the latest tag from Docker Registry..."
    latestTag=$(az acr repository show-tags --name linuxappreg --repository azuretest01 --orderby time_desc --top 1 --output tsv)
    echo "##vso[task.setvariable variable=DockerImageTag]$latestTag"
  displayName: 'Get Latest Docker Image Tag'

- task: AzureRmWebAppDeployment@4
  displayName: 'Azure App Service Deploy: ap012'
  inputs:
    azureSubscription: '********-****-****-****-************'  # サブスクリプションIDを伏字にしています
    appType: webAppContainer
    WebAppName: ap012
    DockerNamespace: linuxappreg.azurecr.io
    DockerRepository: azuretest01
    DockerImageTag: $(DockerImageTag)
```

利点
レジストリ内の実際の最新イメージをデプロイするため、より正確なデプロイが可能です。
特定のバージョンやルールに従ったタグを管理している場合に適しています。
