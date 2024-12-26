# powershell-scripts-collection

Windowsとそのアプリケーション、およびWSL（Windows Subsystem for Linux）の操作を簡素化するPowerShellスクリプト集です。

## 目次

- [powershell-scripts-collection](#powershell-scripts-collection)
  - [目次](#目次)
  - [スクリプト一覧](#スクリプト一覧)
    - [open-explorer-wsl.ps1](#open-explorer-wslps1)
    - [open-explorer-wsl-folder-action.ps1](#open-explorer-wsl-folder-actionps1)
    - [create-ps1-shortcut.ps1](#create-ps1-shortcutps1)
    - [open-folder-videofiles-with-losslesscut.ps1](#open-folder-videofiles-with-losslesscutps1)
  - [使用方法](#使用方法)
    - [要件](#要件)
    - [セキュリティ設定](#セキュリティ設定)
      - [一時的にプロセスの実行ポリシーを変更（推奨）](#一時的にプロセスの実行ポリシーを変更推奨)
      - [現在のユーザーに対して実行ポリシーを変更](#現在のユーザーに対して実行ポリシーを変更)
      - [スクリプトをローカルで信頼済みとして扱う](#スクリプトをローカルで信頼済みとして扱う)
  - [ライセンス](#ライセンス)

## スクリプト一覧

### [open-explorer-wsl.ps1](./scripts/open-explorer-wsl.ps1)

WSLのフォルダをWindows Explorerで開くシンプルなツール。

- 指定したWSLパスをエクスプローラーで開く
- コマンドライン引数でターゲットフォルダを指定可能

### [open-explorer-wsl-folder-action.ps1](./scripts/open-explorer-wsl-folder-action.ps1)

WSLのフォルダ構造をGUI（WPF）で表示し、操作するツール。

- フォルダのブラウズと移動
- エクスプローラーでフォルダを開く
- WSL上のVSCodeでフォルダを開く
- 上位フォルダへの移動
- デバッグモード対応

### [create-ps1-shortcut.ps1](./scripts/create-ps1-shortcut.ps1)

PowerShellスクリプト（.ps1）のショートカットを作成するためのGUIツール。

- ファイル選択ダイアログでps1ファイルを選択
- 選択したスクリプトと同じディレクトリにショートカットを作成
- デバッグモード対応

### [open-folder-videofiles-with-losslesscut.ps1](./scripts/open-folder-videofiles-with-losslesscut.ps1)

選択したフォルダ内の動画ファイルをLosslessCutで複数起動するスクリプト

- 複数の動画フォーマットに対応
- 再帰的なファイル検索
- LosslessCutの複数インスタンス実行対応

## 使用方法

各スクリプトの詳細な使用方法は、スクリプトファイル内のコメントを参照してください。

### 要件

- Windows 10/11
- PowerShell 5.1以上、または、PowerShell Core (pwsh)
- WSL2（WSL関連スクリプトの場合）
- .NET Framework（GUIツールの場合）

### セキュリティ設定

PowerShellスクリプトを実行するには、適切な実行ポリシーを設定する必要があります。
以下のいずれかの方法で設定してください。

#### 一時的にプロセスの実行ポリシーを変更（推奨）

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

#### 現在のユーザーに対して実行ポリシーを変更

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

#### スクリプトをローカルで信頼済みとして扱う

スクリプトが信頼できるものであることが確実であれば、スクリプトファイルのプロパティを変更する方法もあります。

1. スクリプトファイルを右クリックし、「プロパティ」を選択。
2. 「全般」タブの下部にある「ブロックの解除」チェックボックスを有効にする。
3. 「適用」または「OK」をクリック。
4. 再度スクリプトを実行する。

## ライセンス

[MIT License](./LICENSE)
