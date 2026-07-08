# powershell-scripts-collection

Windowsとそのアプリケーション、WSL（Windows Subsystem for Linux）、およびClaude Codeの操作を簡素化するPowerShellスクリプト集です。

## 目次

- [powershell-scripts-collection](#powershell-scripts-collection)
  - [目次](#目次)
  - [ディレクトリ構成](#ディレクトリ構成)
  - [スクリプトカテゴリ](#スクリプトカテゴリ)
  - [使用方法](#使用方法)
    - [要件](#要件)
    - [セキュリティ設定](#セキュリティ設定)
      - [一時的にプロセスの実行ポリシーを変更（推奨）](#一時的にプロセスの実行ポリシーを変更推奨)
      - [現在のユーザーに対して実行ポリシーを変更](#現在のユーザーに対して実行ポリシーを変更)
      - [スクリプトをローカルで信頼済みとして扱う](#スクリプトをローカルで信頼済みとして扱う)
  - [ライセンス](#ライセンス)

## ディレクトリ構成

スクリプトは用途別に `scripts/` 配下のサブディレクトリへ分類しています。
各スクリプトの詳細は、各ディレクトリのREADMEを参照してください。

```text
scripts/
├── folder/       # エクスプローラー／フォルダ操作系
├── losslesscut/  # 動画ファイルをLosslessCutで起動
├── powershell/   # PowerShellスクリプト関連
├── claudecode/   # Claude Code関連
└── video/        # 動画変換関連（ffmpeg再エンコード）
```

## スクリプトカテゴリ

| カテゴリ | 概要 | スクリプト |
| --- | --- | --- |
| [folder](./scripts/folder/) | エクスプローラー／フォルダ操作系 | `open-explorer-wsl.ps1` / `open-explorer-wsl-folder-action.ps1` |
| [losslesscut](./scripts/losslesscut/) | 動画ファイル操作（LosslessCut連携） | `open-folder-videofiles-with-losslesscut.ps1` |
| [powershell](./scripts/powershell/) | PowerShellスクリプト関連 | `create-ps1-shortcut.ps1` |
| [claudecode](./scripts/claudecode/) | Claude Code関連 | `Install-Skill.ps1` |
| [video](./scripts/video/) | 動画変換関連（ffmpeg再エンコード） | `VideoReencoder.ps1` |

## 使用方法

各スクリプトの詳細な使用方法は、各ディレクトリのREADME、およびスクリプトファイル内のコメントを参照してください。

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
