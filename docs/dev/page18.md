# Azure DevOpsでPull Request作成時に承認者を含むTeams通知を送る方法

はじめに
開発プロジェクトでコードの品質を確保するためにPull Request (PR) のプロセスは非常に重要です。Pull Requestを作成した際に、迅速な承認やレビューを促すためにMicrosoft Teamsに通知を送ることは、チームのコミュニケーションを向上させるのに役立ちます。この記事では、Azure DevOpsのPull Request作成時に、承認者を含むカスタマイズされた通知をMicrosoft Teamsに送信する方法を紹介します。

必要なツール
- Azure DevOpsアカウント
- Microsoft Teamsチャネル
- Azure FunctionまたはLogic Apps

## 1. TeamsにAzure DevOps Connectorを追加する
まず、Microsoft TeamsにAzure DevOps Connectorを追加し、Pull Request作成時の通知を受け取れるようにします。

手順:
1. Teamsの通知を受け取りたいチャネルを開きます。
1. 右上の「...」メニューをクリックし、「Connector」を選択します。
1. 「Azure DevOps」コネクタを検索し、チャネルに追加します。
1. Azure DevOpsのプロジェクトやリポジトリを選択し、通知のトリガーとなるイベントを設定します。
1. 最後に、生成されたWebhook URLをコピーします。

## 2. Azure DevOpsでService Hookを設定する
次に、Azure DevOpsのPull Request作成イベントをトリガーとして、Teamsに通知を送るためのService Hookを設定します。

手順:
1. Azure DevOpsのプロジェクトページに移動し、「Project Settings」を開きます。
1. 「Service Hooks」を選択し、「Create Subscription」をクリックします。
1. 「Web Hooks」を選び、「Next」をクリックします。
1. 「Trigger on this type of event」で「Pull Request Created」を選択します。
1. 「Next」をクリックし、先ほどコピーしたTeamsのWebhook URLを入力します。
1. 通知を制限する場合（例: 特定のブランチのみ通知するなど）、その条件を設定し、完了します。

## 3. Azure Functionを使ってカスタマイズされた通知を送信する
Azure DevOpsのPull Requestイベントを受け取り、承認者（Reviewers）の情報を含む通知をTeamsに送るために、Azure Functionを作成します。

手順:
1. Azure Portalにアクセスし、新しい「Function App」を作成します。
1. Function Appが作成されたら、「Functions」メニューから「HTTP Trigger」テンプレートを使って新しいFunctionを作成します。
以下のコードをFunctionに追加します。
```csharp
コードをコピーする
using System.IO;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

public static async Task<IActionResult> Run(HttpRequest req, ILogger log)
{
    log.LogInformation("C# HTTP trigger function processed a request.");

    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JObject.Parse(requestBody);

    string prTitle = data.resource.title;
    string prCreator = data.resource.createdBy.displayName;
    string prUrl = data.resource.url;

    // 承認者リストの取得
    var reviewers = data.resource.reviewers;
    StringBuilder reviewersList = new StringBuilder();
    foreach (var reviewer in reviewers)
    {
        reviewersList.Append(reviewer.displayName + ", ");
    }

    string webhookUrl = "YOUR_TEAMS_WEBHOOK_URL";

    var payload = new
    {
        text = $"New Pull Request Created: {prTitle}\nCreated by: {prCreator}\nReviewers: {reviewersList.ToString().TrimEnd(' ', ',')}\nPR URL: {prUrl}"
    };

    using (var client = new HttpClient())
    {
        var json = new StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json");
        await client.PostAsync(webhookUrl, json);
    }

    return new OkObjectResult("Notification sent");
}
```
作成したFunctionを保存し、そのFunctionのエンドポイントURLをコピーします。
## 4. Azure DevOpsのService HookにFunction URLを設定する
Service Hookに戻り、FunctionのURLをAzure DevOpsのWebhook URLとして設定します。これにより、Pull Requestが作成された際に、承認者情報を含む通知がTeamsに送信されます。