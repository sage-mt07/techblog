---
layout: default
title: "KSQLDB概要"
category: "KAFKA"
---

# KSQL（ksqlDB）の概要
**KSQL（現在はksqlDBと呼ばれる）**は、Apache Kafka上でリアルタイムのストリーム処理を容易にするためのストリームクエリ言語です。SQLライクな構文を使用して、データストリームのフィルタリング、変換、集約、結合などの操作を直感的に行うことができます。主な特徴は以下の通りです：

    リアルタイム処理：データがKafkaトピックに流れると同時に処理が行われます。
    スキーマサポート：Avro、JSON、Protobufなどのスキーマをサポートし、データの構造を明確に定義できます。
    インタラクティブなクエリ：CLIやREST APIを通じてインタラクティブにクエリを実行できます。
    スケーラビリティ：Kafkaクラスタと同様に、ksqlDBも水平スケーリングが可能です。
    KSQLを使用するためのインフラ構成と設定
    KSQL（ksqlDB）を利用するためには、以下のインフラ構成と設定が必要です：

1. Apache Kafka クラスター：

Kafkaブローカー、ZooKeeper（またはKafkaの最新バージョンではKRaftモード）を含む基本的なKafkaインフラが必要です。
2. ksqlDB サーバー：

ksqlDBサーバーをデプロイします。これはクエリを実行し、Kafkaと連携してデータストリームを処理します。
必要に応じて、複数のksqlDBサーバーをクラスタリングして高可用性とスケーラビリティを確保します。
3. 設定：

ksql-server.properties ファイルでKafkaブローカーのアドレス、ストリームストレージの場所、リソース設定などを定義します。
必要に応じて、セキュリティ（SSL/TLS、認証、認可）や監視（JMX、Prometheusなど）の設定も行います。
4. クライアントツール：

ksqlDB CLI、REST API、またはKafka Connectなどのツールを使用して、ksqlDBと対話します。
例：ksqlDBサーバーの基本的な起動コマンド

bash
``` 
ksql-server-start /etc/ksql/ksql-server.properties
``` 
## KSQLに必要なクエリとトピックの関係
KSQL（ksqlDB）では、クエリとKafkaトピックは密接に関連しています。主な関係は以下の通りです：

1. ソーストピック：

クエリの入力となる既存のKafkaトピックです。ストリームやテーブルとして定義され、データをリアルタイムで処理します。
2. シークエンスクエリ：

SQLライクなクエリを使用して、ソーストピックからデータを読み取り、フィルタリング、変換、集約、結合などの操作を行います。
3. シンクトピック：

クエリの結果を新たなKafkaトピックに出力します。これにより、処理結果を他のアプリケーションやサービスで利用可能にします。
4. 永続化されたクエリ：

クエリは永続的に実行され、ソーストピックに新しいデータが到着するたびに自動的に処理されます。
例：ストリームの作成とクエリの実行
```
sql
コピーする
-- ソースストリームの作成
CREATE STREAM input_stream (
    id INT,
    name VARCHAR,
    amount DOUBLE
) WITH (
    KAFKA_TOPIC='input_topic',
    VALUE_FORMAT='JSON'
);

-- 集約クエリの実行
CREATE TABLE aggregated_table AS
    SELECT name, SUM(amount) AS total_amount
    FROM input_stream
    GROUP BY name;
```
この例では、input_topic というKafkaトピックからデータを読み取り、input_stream ストリームを作成します。その後、input_stream を基に aggregated_table テーブルを作成し、名前ごとの金額の合計を集約しています。集約結果は新しいKafkaトピック（デフォルトでは aggregated_table と同名）に出力されます。

## サンプルコード
以下に、ksqlDBを使用してシンプルなストリーム処理を行うサンプルコードを示します。

1. ソーストピックの作成（Kafkaトピックの前提）

bash
```
kafka-topics --create --topic orders --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```
2. ストリームの定義

sql
```
CREATE STREAM orders_stream (
    order_id INT,
    customer VARCHAR,
    amount DOUBLE,
    order_time TIMESTAMP
) WITH (
    KAFKA_TOPIC='orders',
    VALUE_FORMAT='JSON',
    TIMESTAMP='order_time'
);
```
3. 単純なフィルタリングクエリ

sql
```
CREATE STREAM large_orders AS
    SELECT *
    FROM orders_stream
    WHERE amount > 1000;
```
このクエリは、orders_stream から金額が1000を超える注文のみを抽出し、新しいストリーム large_orders として出力します。

4. 集約クエリ

sql
```
CREATE TABLE total_sales_per_customer AS
    SELECT customer, SUM(amount) AS total_sales
    FROM orders_stream
    GROUP BY customer;
```
このクエリは、各顧客ごとの総売上を集計し、テーブル total_sales_per_customer に保存します。

5. クエリの実行と結果の確認

bash
```
# ksqlDB CLIに接続
ksql

# クエリの実行
SELECT * FROM large_orders EMIT CHANGES;

# 集計結果の確認
SELECT * FROM total_sales_per_customer EMIT CHANGES;
```
6. データの投入（別のターミナルで実行）

bash
```
kafka-console-producer --topic orders --bootstrap-server localhost:9092 --property "parse.key=true" --property "key.separator=:"
>{"order_id":1,"customer":"Alice","amount":1500,"order_time": "2025-01-25T10:00:00Z"}
>{"order_id":2,"customer":"Bob","amount":500,"order_time": "2025-01-25T10:05:00Z"}
>{"order_id":3,"customer":"Alice","amount":2000,"order_time": "2025-01-25T10:10:00Z"}
```
このサンプルでは、orders トピックに3件の注文データを投入しています。large_orders ストリームには金額が1500と2000の注文がフィルタリングされて出力され、total_sales_per_customer テーブルにはAliceの総売上が3500、Bobの売上が500として集計されます。

以上が、KafkaのKSQL（ksqlDB）に関する概要、インフラ構成と設定、クエリとトピックの関係、及びサンプルコードのまとめです。これらを基に、リアルタイムのデータストリーム処理を効果的に実装することが可能です。