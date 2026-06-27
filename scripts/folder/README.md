# folder（フォルダ操作）

エクスプローラー／フォルダ操作系のPowerShellスクリプトです。

## スクリプト一覧

### [open-explorer-wsl.ps1](./open-explorer-wsl.ps1)

WSLのフォルダをWindows Explorerで開くシンプルなツール。

- 指定したWSLパスをエクスプローラーで開く
- コマンドライン引数でターゲットフォルダを指定可能

```powershell
# ホームディレクトリを開く
.\open-explorer-wsl.ps1

# ホームディレクトリ配下のフォルダを開く
.\open-explorer-wsl.ps1 -TargetFolder "dev/projects"
```

### [open-explorer-wsl-folder-action.ps1](./open-explorer-wsl-folder-action.ps1)

WSLのフォルダ構造をGUI（WPF）で表示し、操作するツール。

- フォルダのブラウズと移動
- エクスプローラーでフォルダを開く
- WSL上のVSCodeでフォルダを開く
- 上位フォルダへの移動
- フォルダの昇順・降順表示
- デバッグモード対応

```powershell
# 通常モード
.\open-explorer-wsl-folder-action.ps1

# デバッグモード
.\open-explorer-wsl-folder-action.ps1 -Debug
```

### [open-folder-videofiles-with-losslesscut.ps1](./open-folder-videofiles-with-losslesscut.ps1)

選択したフォルダ内の動画ファイルをLosslessCutで複数起動するスクリプト。

- 複数の動画フォーマットに対応
- 再帰的なファイル検索
- LosslessCutの複数インスタンス実行対応

実行前に、スクリプト先頭の `$losslessCutPath` をご利用環境の `LosslessCut.exe` のパスに合わせて変更してください。
また、LosslessCutの設定で「同時に複数のインスタンスを実行する（実験的）」を有効にしてください。

## 補足

- WSL関連スクリプトは `\\wsl.localhost\Ubuntu` を起点に動作します（ディストリビューションが異なる場合はスクリプト内のパスを調整してください）。
- 各スクリプトの詳細はファイル先頭のコメント（comment-based help）を参照してください。
