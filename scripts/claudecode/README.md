# claudecode（Claude Code関連）

Claude Codeの設定・運用を補助するスクリプトです。

## スクリプト一覧

### [Install-Skill.ps1](./Install-Skill.ps1)

Claude Codeのスキル（SKILL.md）をインストールするためのスクリプト。

- `~/Documents/import_skills/<Name>/SKILL.md` を `~/.claude/skills/<Name>/SKILL.md` へコピー
- コピー先ディレクトリを自動作成
- コピー後に先頭5行を表示して内容を確認
- `~/.claude/CLAUDE.md` へ追記するテンプレートを出力

```powershell
.\Install-Skill.ps1 -Name "skill-name"
```

## 補足

- `~/Documents/import_skills/<Name>/SKILL.md` が存在しない場合はエラーで終了します。事前にインストール元へSKILL.mdを配置してください。
- CLAUDE.mdへの追記は自動化していません。出力されるテンプレートを確認・編集してから手動で実行してください。
