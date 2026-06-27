<#
.SYNOPSIS
Claude Codeのスキル（SKILL.md）をインストールするスクリプト

.DESCRIPTION
インポート元（~/Documents/import_skills/<Name>/SKILL.md）から、
Claude Codeのスキルディレクトリ（~/.claude/skills/<Name>/SKILL.md）へSKILL.mdをコピーします。

機能：
- コピー先ディレクトリの自動作成
- コピー後に先頭5行を表示して内容を確認
- ~/.claude/CLAUDE.md へ追記するためのテンプレートを出力（追記は手動）

.PARAMETER Name
インストールするスキル名。
コピー元 ~/Documents/import_skills/<Name>/SKILL.md とコピー先 ~/.claude/skills/<Name>/ の <Name> に対応します。

.NOTES
ファイル名: Install-Skill.ps1
作成者: 7rikazhexde
作成日: 2026/06/27
バージョン: 0.1.0

このスクリプトはUTF-8 with BOM エンコーディングで保存してください。

注意事項：
1. コピー元の ~/Documents/import_skills/<Name>/SKILL.md が存在しない場合はエラーで終了します。
2. CLAUDE.md への追記は自動化していません。出力されるテンプレートを確認・編集してから手動で実行してください。

.EXAMPLE
.\Install-Skill.ps1 -Name "skill-name"
~/Documents/import_skills/skill-name/SKILL.md を ~/.claude/skills/skill-name/SKILL.md へインストールします。
#>

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
# 単一引用符 here-string（@'...'@）を使い、テンプレート内の "@ を入れ子終端と誤認させない。
# スキル名は __SKILL_NAME__ プレースホルダを後から置換する。
$claudeMdTemplate = @'

--- CLAUDE.md 追記テンプレート ---
以下の内容を確認・編集してから CLAUDE.md に追記してください。

Add-Content -Path "$HOME\.claude\CLAUDE.md" -Value @"

## [条件をここに記載]

[条件をここに記載] 場合は、
必ず ~/.claude/skills/__SKILL_NAME__/SKILL.md を読んでからその規範に従うこと。
"@ -Encoding utf8
-----------------------------------
'@

Write-Host ($claudeMdTemplate -replace '__SKILL_NAME__', $Name)
