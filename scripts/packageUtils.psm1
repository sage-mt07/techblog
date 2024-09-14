# File: Scripts/PackageUtils.psm1

function Get-PackageInfoFromNupkg {
    param (
        [Parameter(Mandatory = $true)]
        [string]$NupkgPath
    )

    if (-not (Test-Path $NupkgPath)) {
        Write-Error "指定された .nupkg ファイルが存在しません: $NupkgPath"
        return $null
    }

    # 一時ディレクトリを作成
    $tempDir = New-TemporaryFile | Remove-Item -Force -Confirm:$false -ErrorAction SilentlyContinue
    $tempDir = Split-Path $tempDir
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # .nupkgファイルを解凍
        Expand-Archive -Path $NupkgPath -DestinationPath $tempDir -Force

        # 解凍先から .nuspec ファイルを検索
        $nuspecFile = Get-ChildItem -Path $tempDir -Recurse -Filter *.nuspec | Select-Object -First 1

        if ($null -eq $nuspecFile) {
            Write-Error ".nupkg ファイル内に .nuspec ファイルが見つかりませんでした。"
            return $null
        }

        # .nuspecファイルをXMLとして読み込む
        [xml]$nuspecContent = Get-Content $nuspecFile.FullName

        # パッケージ名とバージョンを取得
        $packageName = $nuspecContent.package.metadata.id
        $packageVersion = $nuspecContent.package.metadata.version

        return @{ Name = $packageName; Version = $packageVersion }
    }
    finally {
        # 一時ディレクトリを削除
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
