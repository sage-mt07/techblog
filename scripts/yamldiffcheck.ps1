# PSYaml モジュールのインポート
Import-Module powershell-yaml

# YAML ファイルの読み込み
$devYaml = ConvertFrom-Yaml (Get-Content -Path "dev.yaml" -Raw)
$prodYaml = ConvertFrom-Yaml (Get-Content -Path "prod.yaml" -Raw)

# YAML の比較（再帰的に差分を検出、一致部分を除外）
function Compare-Yaml {
    param ($dev, $prod)

    $devDiff = @{}
    $prodDiff = @{}

    foreach ($key in $prod.Keys) {
        if ($dev.ContainsKey($key)) {
            # 値がハッシュテーブルの場合、再帰的に比較して一致部分を除外
            if ($dev[$key] -is [hashtable] -and $prod[$key] -is [hashtable]) {
                $nestedDevDiff, $nestedProdDiff = Compare-Yaml $dev[$key] $prod[$key]

                # 差分が存在しない場合は無視（完全に一致している場合）
                if ($nestedDevDiff.Count -eq 0 -and $nestedProdDiff.Count -eq 0) {
                    continue
                }

                # 差分が存在する場合のみ追加
                if ($nestedDevDiff.Count -gt 0) {
                    $devDiff[$key] = $nestedDevDiff
                }
                if ($nestedProdDiff.Count -gt 0) {
                    $prodDiff[$key] = $nestedProdDiff
                }
            }
            # 値がリストの場合、個々の要素を比較して一致部分を除外
            elseif ($dev[$key] -is [array] -and $prod[$key] -is [array]) {
                $listDevDiff, $listProdDiff = Compare-List $dev[$key], $prod[$key]
                if ($listDevDiff.Count -gt 0) {
                    $devDiff[$key] = $listDevDiff
                }
                if ($listProdDiff.Count -gt 0) {
                    $prodDiff[$key] = $listProdDiff
                }
            }
            # 値が異なる場合のみ差分として追加
            elseif ($dev[$key] -ne $prod[$key]) {
                $devDiff[$key] = $dev[$key]
                $prodDiff[$key] = $prod[$key]
            }
        } else {
            # dev に存在しない場合は prod の新しい項目として prod_diff に追加
            $prodDiff[$key] = $prod[$key]
        }
    }

    # dev に存在するが prod に存在しない項目を dev_diff に追加
    foreach ($key in $dev.Keys) {
        if (-not $prod.ContainsKey($key)) {
            $devDiff[$key] = $dev[$key]
        }
    }

    return $devDiff, $prodDiff
}

# リストの比較関数（リスト内の要素を比較して差分を抽出）
function Compare-List {
    param ($devList, $prodList)

    $devListDiff = @()
    $prodListDiff = @()

    foreach ($devItem in $devList) {
        $matchFound = $false

        foreach ($prodItem in $prodList) {
            # リスト内の各アイテムを比較し、一致するものがあればフラグを立てる
            if ($devItem.name -eq $prodItem.name -and $devItem.value -eq $prodItem.value) {
                $matchFound = $true
                break
            }
        }

        # dev に存在するが prod に存在しないものを dev_diff に追加
        if (-not $matchFound) {
            $devListDiff += $devItem
        }
    }

    foreach ($prodItem in $prodList) {
        $matchFound = $false

        foreach ($devItem in $devList) {
            if ($prodItem.name -eq $devItem.name -and $prodItem.value -eq $devItem.value) {
                $matchFound = $true
                break
            }
        }

        # prod に存在するが dev に存在しないものを prod_diff に追加
        if (-not $matchFound) {
            $prodListDiff += $prodItem
        }
    }

    return $devListDiff, $prodListDiff
}

# 差分を取得
$devDiff, $prodDiff = Compare-Yaml $devYaml $prodYaml

# dev 側の差分を書き込み
if ($devDiff.Count -gt 0) {
    $devDiff | ConvertTo-Yaml | Out-File -FilePath "dev_diff.yaml"
} else {
    Write-Host "dev_diff.yaml に差分はありません。"
}

# prod 側の差分を書き込み
if ($prodDiff.Count -gt 0) {
    $prodDiff | ConvertTo-Yaml | Out-File -FilePath "prod_diff.yaml"
} else {
    Write-Host "prod_diff.yaml に差分はありません。"

}

Write-Host "処理が完了しました: dev_diff.yaml と prod_diff.yaml"
 