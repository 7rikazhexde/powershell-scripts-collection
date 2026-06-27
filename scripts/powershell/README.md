# powershell（PowerShell関連）

PowerShellスクリプトの運用を補助するスクリプトです。

## スクリプト一覧

### [create-ps1-shortcut.ps1](./create-ps1-shortcut.ps1)

PowerShellスクリプト（.ps1）のショートカットを作成するためのGUIツール。

- ファイル選択ダイアログでps1ファイルを選択
- 選択したスクリプトと同じディレクトリにショートカットを作成
- ショートカット作成後の設定ガイドを表示
- 作成したショートカットの保存先を直接開く機能
- デバッグモード対応

実行にはPowerShell Core (pwsh)を優先的に使用し、未インストールの場合はWindows PowerShell (powershell.exe)にフォールバックします。

```powershell
# 通常モード
.\create-ps1-shortcut.ps1

# デバッグモード
.\create-ps1-shortcut.ps1 -Debug
```

## 補足

- 各スクリプトの詳細はファイル先頭のコメント（comment-based help）を参照してください。
