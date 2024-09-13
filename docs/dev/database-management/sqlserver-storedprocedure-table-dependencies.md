# SQL Serverでストアドプロシージャやテーブルの依存関係を確認する方法

データベースのメンテナンスや変更時に、ストアドプロシージャ（SP）やテーブルの依存関係を把握することは非常に重要です。依存関係を正確に理解することで、意図しない影響を避け、システムの健全性を保つことができます。この記事では、SQL Serverでストアドプロシージャやテーブルの依存関係を効率的に一覧化し、さらにそれが参照（SELECT）操作なのか、更新（INSERT、UPDATE、DELETE）操作なのかを判別する方法を紹介します。

## 1. 依存関係を取得する基本的なクエリ
まず、sys.sql_expression_dependencies を使用して、オブジェクト間の依存関係を取得します。以下は基本的なクエリです。

``` sql コードをコピーする
SELECT 
    referencing_object_name = OBJECT_NAME(d.referencing_id), 
    referencing_object_type = o.type_desc,
    referenced_object_name = OBJECT_NAME(d.referenced_id),
    referenced_object_type = ro.type_desc
FROM 
    sys.sql_expression_dependencies AS d
JOIN 
    sys.objects AS o ON d.referencing_id = o.object_id
JOIN 
    sys.objects AS ro ON d.referenced_id = ro.object_id
ORDER BY 
    referencing_object_name;
```
このクエリにより、どのオブジェクトが他のオブジェクトに依存しているかの基本的な一覧が表示されます。しかし、このままでは依存関係が参照か更新かは分かりません。そこで、次に操作内容を判別する処理を追加していきます。

2. 再帰的な依存関係の取得と操作の判別
ストアドプロシージャやビューが他のオブジェクトにどのように依存しているか（参照か更新か）を判別するためには、再帰的に依存関係をたどりつつ、SQL文の種類を解析します。ここでは、sys.sql_modules を使ってSQL文を解析し、依存関係が更新か参照かを判別します。

``` sql コードをコピーする
WITH RecursiveDependencies AS (
    -- ベースケース: 直接の依存関係を取得
    SELECT 
        referencing_object_name = OBJECT_NAME(d.referencing_id), 
        referencing_object_type = o.type_desc,
        referenced_object_name = OBJECT_NAME(d.referenced_id),
        referenced_object_type = ro.type_desc,
        level = 1, -- 依存の深さ
        sm.definition -- SQLモジュールの定義（ストアドプロシージャやビューのSQLコード）
    FROM 
        sys.sql_expression_dependencies AS d
    JOIN 
        sys.objects AS o ON d.referencing_id = o.object_id
    JOIN 
        sys.objects AS ro ON d.referenced_id = ro.object_id
    JOIN 
        sys.sql_modules AS sm ON d.referencing_id = sm.object_id

    UNION ALL

    -- 再帰ケース: 依存関係を再帰的にたどる
    SELECT 
        referencing_object_name = OBJECT_NAME(d.referencing_id), 
        referencing_object_type = o.type_desc,
        referenced_object_name = r.referenced_object_name,
        referenced_object_type = r.referenced_object_type,
        level = r.level + 1,
        sm.definition
    FROM 
        sys.sql_expression_dependencies AS d
    JOIN 
        sys.objects AS o ON d.referencing_id = o.object_id
    JOIN 
        RecursiveDependencies AS r ON r.referenced_object_name = OBJECT_NAME(d.referencing_id)
    JOIN 
        sys.sql_modules AS sm ON d.referencing_id = sm.object_id
)
-- 処理の種類を判別する部分
SELECT 
    referencing_object_name,
    referencing_object_type,
    referenced_object_name,
    referenced_object_type,
    level,
    CASE 
        WHEN sm.definition LIKE '%INSERT%' OR sm.definition LIKE '%UPDATE%' OR sm.definition LIKE '%DELETE%' THEN '更新'
        WHEN sm.definition LIKE '%SELECT%' THEN '参照'
        ELSE '不明'
    END AS operation_type
FROM 
    RecursiveDependencies AS sm
ORDER BY 
    referencing_object_name, level;
```
# 3. クエリの説明

再帰的に依存関係を取得: WITH RecursiveDependencies AS でCTEを使い、オブジェクト間の依存関係を再帰的に取得します。これにより、深い依存関係もたどり、くし刺し状に表示します。
SQLモジュールの解析: sys.sql_modules.definition からストアドプロシージャやビューのSQLコードを取得し、CASE文を使ってSQL文に SELECT、INSERT、UPDATE、DELETE のいずれが含まれているかをチェックします。
operation_type: 依存関係が参照なのか更新なのかを operation_type 列に表示します。

# 4. 実行結果の例

|referencing_object_name	|referencing_object_type	|referenced_object_name|	referenced_object_type|	level|	operation_type|
| ----	| ----	| ---- |	---- |	---- |	---- |
|ProcedureA|	SQL_STORED_PROCEDURE|	ProcedureB|	SQL_STORED_PROCEDURE|	1|	更新|
|ProcedureA|	SQL_STORED_PROCEDURE|	TableC|	USER_TABLE|	2|	参照|
|ProcedureB|	SQL_STORED_PROCEDURE|	TableC|	USER_TABLE|	1|	参照|

結果の解釈

ProcedureA は ProcedureB を呼び出しており、その中で更新操作が行われているため、更新 として表示されます。
ProcedureA が TableC を参照している場合、参照 として表示されます。
ProcedureB 自身も TableC に対して参照のみ行っているため、参照 として表示されます。

# 5. 注意点

このクエリは、ストアドプロシージャやビュー内のSQL文を解析して処理の種類を判別していますが、複雑な動的SQLや一部の特殊なケースでは正確に解析できないことがあります。
より詳細な解析が必要な場合は、実行時にクエリをキャプチャするなど、追加のツールを使用することも検討してください。