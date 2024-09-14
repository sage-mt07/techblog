# パイプライン参照ブランチを一括で変更する
Azure DevOpsで複数のプロジェクトやパイプラインを管理している場合、ブランチを変更した際にパイプラインが参照しているブランチも自動的に変更する必要があります。この記事では、Azure DevOpsのパイプライン内で System.AccessToken を使ってAPIを呼び出し、複数のパイプラインの参照ブランチやトリガーのブランチを一括で変更する方法について説明します。

## 目次
- System.AccessTokenとは？
- System.AccessTokenをパイプラインで有効にする手順
- UIでの設定
- YAMLでの設定
- リポジトリ側のセキュリティ設定
- パイプライン参照ブランチを一括で変更するスクリプト例
- まとめ

## 1. System.AccessTokenとは？
System.AccessToken は、Azure DevOpsパイプライン内でAzure DevOpsのAPIに安全にアクセスするために使用される自動生成されたトークンです。このトークンを利用することで、パイプラインからリポジトリやビルド定義、その他のAzure DevOpsリソースに対して操作を実行できます。通常は、個別にPersonal Access Token（PAT）を発行してAPIにアクセスしますが、System.AccessToken を使用することで、個別のトークンを用意することなく自動化が可能になります。

## 2. System.AccessTokenをパイプラインで有効にする手順
UIでの設定
Azure DevOpsのクラシックパイプラインやYAMLパイプラインで System.AccessToken を使用するには、次の手順で設定を有効にする必要があります。

パイプラインの編集画面 に移動します。
「オプション」タブの中で、「エージェント ジョブ」セクションにある「このジョブにSystem.AccessTokenを提供する」にチェックを入れます。
これにより、パイプラインが System.AccessToken を使用できるようになります。

YAMLでの設定
YAMLパイプラインを使用している場合は、以下のように persistCredentials: true を設定することで、System.AccessToken が有効化されます。
```yaml コードをコピーする
pool:
  vmImage: 'ubuntu-latest'

steps:
- checkout: self
  persistCredentials: true # System.AccessTokenを有効にする

- task: Bash@3
  inputs:
    targetType: 'inline'
    script: |
      # System.AccessTokenの使用例
      echo "Using System.AccessToken to access Azure DevOps API"
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```
### リポジトリ側のセキュリティ設定
System.AccessToken を使用してAzure DevOps APIにアクセスするためには、リポジトリ側でも適切なセキュリティ設定が必要です。パイプラインがリポジトリやその他のリソースにアクセスできるよう、ビルドサービスアカウントに必要な権限を付与します。

- Azure DevOpsでプロジェクトの「リポジトリ」タブに移動します。
- 右上にある「セキュリティ」をクリックします。
- 「ユーザーまたはグループを選択」フィールドに [プロジェクト名] Build Service と入力し、対象のビルドサービスアカウントを選択します。
- 以下の権限を「許可」に設定します。
    - リポジトリの読み取り（Read）：リポジトリの内容にアクセスできる。
    - リポジトリへの書き込み（Write）：リポジトリへのプッシュが可能。
    - タグの作成（Create tag）：タグの作成が可能。
- 設定を保存します。
また、ビルドサービスアカウントがビルド定義に対するアクセス権限も持っていることを確認してください。以下の権限が適切に設定されている必要があります：

- ビルドの読み取り（Read Build）：ビルドの定義や結果にアクセスできる。
- ビルドのキュー操作（Queue builds）：ビルドのキュー実行が可能。
## 3. パイプライン参照ブランチを一括で変更するスクリプト例
次に、実際にパイプラインの参照ブランチやトリガーブランチを一括で変更するスクリプトの例を紹介します。このスクリプトでは、System.AccessToken を使用して、指定したプロジェクト内のすべてのパイプラインの参照ブランチを新しいブランチに変更します。また、トリガーが設定されている場合、そのトリガーの参照ブランチも一緒に変更します。
```
yaml
コードをコピーする
pool:
  vmImage: 'ubuntu-latest'

steps:
- checkout: self
  persistCredentials: true

- task: Bash@3
  inputs:
    targetType: 'inline'
    script: |
      # プロジェクト名と組織名を設定
      projectName="your-project-name"
      organizationUrl="https://dev.azure.com/your-organization"
      
      # Azure DevOpsのSystem.AccessToken
      token=$SYSTEM_ACCESSTOKEN

      # 新しいブランチ名
      newBranch="refs/heads/new-branch"

      # プロジェクト内のパイプライン一覧を取得
      echo "Fetching pipeline list..."
      pipelineList=$(curl -sS --header "Authorization: Bearer $token" "$organizationUrl/$projectName/_apis/build/definitions?api-version=7.1-preview.1")

      # 各パイプラインの参照ブランチとトリガーブランチを更新
      for pipelineId in $(echo $pipelineList | jq -r '.value[].id'); do
        echo "Processing pipeline ID $pipelineId..."
        pipelineUri="$organizationUrl/$projectName/_apis/build/definitions/$pipelineId?api-version=7.1-preview.1"
        pipelineData=$(curl -sS --header "Authorization: Bearer $token" "$pipelineUri")

        # 参照ブランチの変更
        updatedPipeline=$(echo $pipelineData | jq --arg branch "$newBranch" '.repository.defaultBranch = $branch')

        # トリガーが存在するか確認し、トリガーのブランチも更新
        triggerExists=$(echo $pipelineData | jq '.triggers')
        if [ "$triggerExists" != "null" ]; then
          echo "Trigger found. Updating trigger branch to $newBranch..."
          updatedPipeline=$(echo $updatedPipeline | jq --arg branch "$newBranch" '.triggers[].branchFilters[] = $branch')
        fi

        # パイプライン定義を更新
        curl -X PUT -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data "$updatedPipeline" "$pipelineUri"

        echo "Pipeline ID $pipelineId has been updated to branch $newBranch."
      done
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```
## 4. まとめ
System.AccessToken を使用することで、Azure DevOpsのAPIに対して安全かつ簡単にアクセスし、パイプラインの設定を動的に変更することが可能です。特に、複数のプロジェクトやパイプラインが存在する場合、手動でパイプラインの参照ブランチを変更するのは煩雑ですが、今回紹介したスクリプトを使うことで、自動化が容易になります。

- UIまたはYAMLでSystem.AccessTokenを有効化 して、安全にAPIにアクセスする。
- リポジトリ側でビルドサービスに必要な権限を付与 し、アクセスを許可する。
- 複数のパイプラインの参照ブランチやトリガーブランチを一括で更新 するスクリプトを使って作業を効率化する。