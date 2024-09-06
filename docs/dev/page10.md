sed を使った文字列の置き換えや追加は、Dockerfile内でも同様に使用可能です。ただし、Dockerfileの書き方に適応させる必要があります。Dockerfileでは、RUN コマンドを使ってシェルスクリプトのようなコマンドを実行します。

以下は、Dockerfileの中でsedを使ってファイルの内容を置き換え、必要なら追加する例です。

```
FROM alpine:3.12

# 必要なツールをインストール
RUN apk add --no-cache bash sed

# テスト用のファイルを作成
RUN echo "old_string" > /tmp/sample.txt

# sedを使って文字列を入れ替え、なければ追加
RUN if grep -q "old_string" /tmp/sample.txt; then \
      sed -i 's/old_string/new_string/g' /tmp/sample.txt; \
    else \
      echo "new_string" >> /tmp/sample.txt; \
    fi
```

# 結果を確認

RUN cat /tmp/sample.txt

Dockerfileの流れ

FROM alpine:3.12: Alpine Linuxの軽量ベースイメージを使用します。

RUN apk add --no-cache bash sed: bash と sed コマンドをインストールします。

RUN echo "old_string" > /tmp/sample.txt: テスト用にファイルを作成し、old_stringを含む文字列を追加します。

RUN if ... fi: sedを使って、ファイルにold_stringがあればnew_stringに置き換え、なければnew_stringを追加します。

RUN cat /tmp/sample.txt: 結果を確認するためにファイル内容を表示します。