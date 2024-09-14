# File: script/CommitReadme.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$ProjectDirectory,

    [Parameter(Mandatory = $true)]
    [string]$BranchName
)

# Git設定
git config user.email "build@yourdomain.com"
git config user.name "Build Agent"

# 変更があるか確認
$hasChanges = git status --porcelain

if ($hasChanges) {
    # 変更を追加
    git add "$ProjectDirectory/readme.md"

    # コミット
    git commit -m "Update readme.md with latest package versions for $(Split-Path -Leaf $ProjectDirectory)"

    # 新しいブランチを作成してプッシュ
    git checkout -b "$BranchName"
    git push origin "$BranchName"
} else {
    Write-Host "No changes detected in readme.md for $ProjectDirectory."
}
