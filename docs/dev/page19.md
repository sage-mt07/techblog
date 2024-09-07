# Azure DevOpsでPull Request作成時にTeams通知を送る方法【承認者も通知】

Azure DevOpsでPull Request（PR）が作成された際、チームメンバーに即座に通知が届くように設定したい場合があります。特に、PRの承認者を含む通知を送ることで、スムーズな承認プロセスを促進できます。今回は、Azure FunctionsやLogic Appsを使わず、Azure DevOpsのService HooksとMicrosoft TeamsのWebhookを利用して、このプロセスを実現する方法を紹介します。

手順の概要
1. Azure DevOpsでService Hooksを設定してPull Requestイベントを監視
1. Microsoft TeamsのWebhookを利用して通知を送信
1. 承認者を含めたカスタムメッセージをTeamsに送る
それでは、具体的な手順を見ていきましょう。

## 1. Azure DevOpsでService Hooksを設定する
Azure DevOpsのService Hooksは、特定のイベントが発生したときに外部サービス（ここではMicrosoft Teams）へ通知を送ることができる機能です。まずは、Pull Requestが作成されたときにTeamsに通知を送る設定を行います。

Service Hooksの設定手順
1. Azure DevOpsにサインインし、対象のプロジェクトに移動します。
1. プロジェクト設定 → Service Hooksを選択します。
1. + Create Subscription (サブスクリプションを作成) ボタンをクリックします。
1. イベントリストの中からMicrosoft Teamsを選びます。
1. イベントタイプとしてPull Request createdを選択します。
1. 通知を送るPull Requestの条件（リポジトリやブランチなど）を設定し、Teamsに通知を送りたいタイミングを指定します。
これで、Azure DevOpsからPull Requestが作成されるたびに、Teamsに通知が送られる準備ができました。

## 2. Microsoft TeamsのWebhookを設定する
次に、Teams側で通知を受け取るためにIncoming Webhookを設定します。このWebhook URLをAzure DevOpsに連携させます。

TeamsのWebhook設定手順
1. Microsoft Teamsを開き、通知を送りたいチャネルに移動します。
1. チャネルの右上にある「…」メニューからConnectorsを選択します。
1. 検索バーでIncoming Webhookを検索し、セットアップを開始します。
1. Webhook名を設定し、WebhookのURLをコピーしておきます。
これで、Teamsのチャネルが通知を受け取る準備が整いました。

## 3. Azure DevOpsでWebhookを設定してTeamsに通知を送る
次に、先ほどコピーしたTeamsのWebhook URLを使って、Azure DevOpsのService Hooksを設定します。

Webhook URLの設定手順
1. Azure DevOpsのService Hooksの設定画面に戻ります。
1. TeamsのWebhook URLをWebhook URL欄に貼り付けます。
1. 通知メッセージのフォーマットをカスタマイズします。PR作成者や承認者の情報を含めたい場合、ペイロードを調整して必要な情報をメッセージに含めるようにします。
1. 最後に設定を保存します。
これで、Pull Requestが作成されたときに、指定したTeamsチャネルにPRの作成者や承認者を含む通知が送信されるようになります。

## ペイロードのカスタマイズ
通知メッセージに含める情報は、Azure DevOpsのWeb Hooksのペイロードとして送られるデータを利用してカスタマイズが可能です。たとえば、承認者情報やPRのタイトル、作成者などをTeamsメッセージに含めることで、PRに関する重要な情報をチームに即時に伝えることができます。