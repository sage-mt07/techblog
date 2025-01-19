---
layout: default
title: "PythonでKustomize用のkustomization.yamlに2つのYAMLファイルの差分を出力する方法"
category: "Containers Orchestration"
---
# PythonでKustomize用のkustomization.yamlに2つのYAMLファイルの差分を出力する方法
Kubernetesを使用していると、異なる環境や設定ファイル間での差分を管理したいケースがよくあります。Kustomizeは、複数のYAMLファイルを管理し、必要に応じてカスタマイズできる強力なツールですが、時にはファイル間の違いを明確にし、どこが変更されたかを把握したい場合があります。

この記事では、Pythonを使って2つのKubernetes YAMLファイルの差分を比較し、その結果をkustomization.yamlに出力するツールの作成方法を解説します。これにより、異なる設定の変更をKustomizeで簡単に反映できるようになります。

## 必要な環境
まず、Pythonをインストールする必要があります。以下の手順に従って、Python実行環境をセットアップし、必要なライブラリをインストールしましょう。

### 1. Pythonのインストール
    Windows:
        Python公式サイトからインストーラをダウンロードし、インストールしてください。インストール時に「Add Python to PATH」にチェックを入れることを忘れないでください。
    Mac:
        MacではHomebrewを使って簡単にインストールできます。ターミナルを開き、以下のコマンドを実行します。

```bash コードをコピーする
brew install python
```
Linux:
Linuxディストリビューションには多くの場合Pythonがプリインストールされていますが、インストールされていない場合は以下のコマンドでインストールできます（Ubuntuの場合）。

```bashコードをコピーする
sudo apt update
sudo apt install python3
```

### 2. 仮想環境の作成
依存関係を管理するために、Pythonの仮想環境を作成します。

仮想環境を作成するディレクトリに移動し、次のコマンドで仮想環境を作成します。

```bashコードをコピーする
python -m venv myenv
```
仮想環境を有効化します。

Windows:

```bashコードをコピーする
myenv\Scripts\activate
```
Mac/Linux:

```bashコードをコピーする
source myenv/bin/activate
```
仮想環境が有効になると、コマンドラインに仮想環境名が表示されます。

### 3. 必要なパッケージのインストール
PyYAMLというライブラリを使用してYAMLファイルを読み込むため、次のコマンドを実行してインストールします。

```bash コードをコピーする
pip install pyyaml
```
Pythonスクリプトの作成
次に、2つのYAMLファイルを比較し、その差分をkustomization.yamlに出力するPythonスクリプトを作成します。以下は、そのサンプルコードです。

```pythonコードをコピーする
import yaml
import difflib
import os

def load_yaml(file_path):
    with open(file_path, 'r') as stream:
        return yaml.safe_load(stream)

def compare_yaml(file1, file2):
    with open(file1, 'r') as f1, open(file2, 'r') as f2:
        file1_lines = f1.readlines()
        file2_lines = f2.readlines()
        
    diff = list(difflib.unified_diff(file1_lines, file2_lines, fromfile=file1, tofile=file2))
    
    return diff

def create_kustomization_yaml(diff_output, output_dir='.', output_file='kustomization.yaml'):
    kustomization = {
        'diff': diff_output
    }

    with open(os.path.join(output_dir, output_file), 'w') as f:
        yaml.dump(kustomization, f)

def main(file1, file2, output_dir='.'):
    # YAMLファイルをロード
    yaml1 = load_yaml(file1)
    yaml2 = load_yaml(file2)
    
    # 差分を比較
    diff = compare_yaml(file1, file2)

    # kustomization.yamlに差分を出力
    create_kustomization_yaml(diff, output_dir)

if __name__ == '__main__':
    # 使用例
    file1_path = 'base.yaml'  # 1つ目のYAMLファイル
    file2_path = 'overlay.yaml'  # 2つ目のYAMLファイル
    output_directory = './'  # kustomization.yamlの出力ディレクトリ

    main(file1_path, file2_path, output_directory)
```
スクリプトの内容
- load_yaml: YAMLファイルを読み込む関数です。
- compare_yaml: difflib.unified_diffを使用して2つのファイルを比較し、その差分を取得します。
- create_kustomization_yaml: 取得した差分をkustomization.yamlファイルに出力します。
- main: 2つのYAMLファイルを読み込み、差分を比較してkustomization.yamlに出力します。

使い方
作成したPythonスクリプトをファイルとして保存します（例：diff_to_kustomize.py）。
2つのYAMLファイル（base.yamlとoverlay.yamlなど）を同じディレクトリに配置します。
以下のコマンドを実行してスクリプトを実行します。

```bashコードをコピーする
python diff_to_kustomize.py
```

これで、kustomization.yamlが生成され、差分が以下のように出力されます。

```yamlコードをコピーする
diff:
  - "--- base.yaml\n"
  - "+++ overlay.yaml\n"
  - "@@ -1,5 +1,6 @@\n"
  - " apiVersion: v1\n"
  - " kind: Pod\n"
  - "-metadata:\n"
  - "+metadata:\n"
  - "   name: base-pod\n"
  - "+  labels:\n"
  - "+    env: dev\n"
```
仮想環境の無効化
作業が終わったら、仮想環境を無効化します。仮想環境を無効にするには、以下のコマンドを実行します。

```bashコードをコピーする
deactivate
```
まとめ
このPythonスクリプトを使用すると、Kubernetesの複数のYAMLファイル間の差分を簡単に取得して、Kustomizeのkustomization.yamlに出力することができます。これにより、異なる環境での設定変更を簡単に管理でき、ファイル間の違いを素早く確認できます。
