---
layout: default
title: "table rowcount出力"
category: "database management"
---

# SQLServer table rowcount

```
USE [YourDatabaseName]; -- ここでYourDatabaseNameを対象のデータベース名に置き換えます

SELECT 
    t.NAME AS TableName,
    p.rows AS RowCounts
FROM 
    sys.tables t
INNER JOIN 
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
WHERE 
    i.index_id <= 1 -- Clustered Index（Primary Key）もしくはHeap（インデックスがない場合）に限定
GROUP BY 
    t.NAME, p.Rows
ORDER BY 
    t.NAME;

```
