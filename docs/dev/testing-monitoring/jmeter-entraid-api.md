# Entra IDを利用したWebAPIの負荷試験をJMeterで行う方法
今回は、Azure Entra IDを使った認証を必要とするWebAPIに対して、JMeterを使用して負荷試験を行う方法をご紹介します。JMeterを用いて、特定のクライアント専用の認証トークンを自動的に取得し、異なるユーザーごとに同時実行でAPIリクエストを行うシナリオを構築します。

## 1. 準備
### 1.1 Azure ADでの事前設定
まず、Azure ADで負荷試験専用のアプリケーション登録を行います。これにより、実際のアプリケーションが使用するものとは異なるクライアントIDとクライアントシークレットを生成します。これは負荷試験用に分離されており、本番環境への影響を最小限に抑えるために重要な手順です。

手順
Azureポータルにアクセスし、Azure Active Directory > アプリの登録を選択。
負荷試験専用の新しいアプリケーションを登録し、クライアントIDとクライアントシークレットを生成します。
APIアクセス権限を追加し、WebAPIにアクセスできるよう必要なスコープを付与します。たとえば、api://{your_api_id}/.default というスコープです。
このアプリケーションを負荷試験専用として設定することで、本番環境で使うものとは異なるクライアント情報が生成されます。

## 2. JMeterスクリプトの設定
JMeterでは、HTTPリクエストを通じてEntra ID認証トークンを自動的に取得し、そのトークンを使用してWebAPIへの負荷をかけます。今回は、20ユーザーを同時実行し、各ユーザーが異なるトークンを使用してAPIリクエストを行います。

### 2.1 CSV Data Set Configの設定
JMeter内で、複数のユーザー資格情報を利用するため、CSV Data Set Configを使用します。これにより、20ユーザー分の資格情報をCSVファイルから読み込みます。

CSVファイルのフォーマット例：

```csv コードをコピーする
user1@example.com,password1
user2@example.com,password2
user3@example.com,password3
...
```
このファイルをJMeterに読み込ませ、各スレッドが異なるユーザー資格情報を利用します。

### 2.2 トークン取得リクエストの設定
各ユーザーがAPIにアクセスするために、認証トークンを取得する必要があります。OAuth 2.0のpasswordフローを利用して、ユーザー資格情報を使いトークンを取得します。

HTTP Request Samplerの設定：

URL：https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
メソッド：POST
Body Data：
```yamlコードをコピーする
client_id=your_jmeter_client_id&
client_secret=your_jmeter_client_secret&
grant_type=password&
username=${USERNAME}&
password=${PASSWORD}&
scope=api://{your_api_id}/.default
```
ここで、client_idとclient_secretは事前に作成したJMeter専用のものを使用します。また、usernameとpasswordはCSV Data Set Configから動的に設定されます。

### 2.3 JSON Extractorの設定
トークン取得リクエストのレスポンスから、access_tokenを抽出するために、JSON Extractorを使用します。これにより、次のAPIリクエストに必要なトークンを抽出します。

JSON Path Expression：$.access_token
変数名：ACCESS_TOKEN
### 2.4 APIリクエストの設定
最後に、取得したACCESS_TOKENを使ってWebAPIにリクエストを送信します。HTTP Header Managerを使い、AuthorizationヘッダーにBearer ${ACCESS_TOKEN}を設定します。

注意: Content-Type ヘッダーの設定は、テスト対象となるAPIによって異なる場合があります。多くの場合、application/json ですが、APIが異なるデータフォーマットを期待する場合は、そのフォーマットに合わせてヘッダーを調整する必要があります。ここでは一般的な例としてapplication/jsonを使用しています。

HTTP Request Samplerの設定：

URL：https://yourapiurl.com/endpoint
メソッド：GET
HTTP Header Managerの設定：
Authorization: Bearer ${ACCESS_TOKEN}
Content-Type: application/json（必要に応じて変更）

## 3. スクリプト実行
JMeterスクリプトを準備し、実行します。各スレッドが異なるユーザー資格情報を使用し、認証トークンを取得し、それを使ってAPIに負荷をかける形になります。スレッド数は同時実行数（20）に設定します。

## 4. 結果の確認
負荷試験が終了した後、JMeterのレポートやログを確認し、各ユーザーのリクエストが正常に処理されたか、レスポンスステータスやエラーを確認します。また、モニタリングツール（例：DatadogやAzure Monitor）を使って、負荷試験中のリソース使用状況やパフォーマンスを監視します。