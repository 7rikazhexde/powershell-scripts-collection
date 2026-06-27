# Install-Skill.ps1
# 使い方: .\Install-Skill.ps1 -Name "skill-name"

param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

$source = "$HOME\Documents\import_skills\$Name\SKILL.md"
$destDir = "$HOME\.claude\skills\$Name"
$dest = "$destDir\SKILL.md"

# ソースファイルの存在確認
if (-not (Test-Path $source)) {
    Write-Error "ファイルが見つかりません: $source"
    exit 1
}

# ディレクトリ作成
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
Write-Host "ディレクトリを作成しました: $destDir"

# ファイルコピー
Copy-Item $source $dest
Write-Host "コピーしました: $source -> $dest"

# 先頭5行を確認
Write-Host "`n--- 確認（先頭5行）---"
Get-Content $dest | Select-Object -First 5

# CLAUDE.md 追記テンプレートを表示
Write-Host @"

--- CLAUDE.md 追記テンプレート ---
以下の内容を確認・編集してから CLAUDE.md に追記してください。

Add-Content -Path "`$HOME\.claude\CLAUDE.md" -Value @"

## [条件をここに記載]

[条件をここに記載] 場合は、
必ず ~/.claude/skills/$Name/SKILL.md を読んでからその規範に従うこと。
"@ -Encoding utf8
-----------------------------------
"@
