# losslesscut（LosslessCut連携）

選択したフォルダ内の動画ファイルをLosslessCutで起動するスクリプトです。

## スクリプト一覧

### [open-folder-videofiles-with-losslesscut.ps1](./open-folder-videofiles-with-losslesscut.ps1)

選択したフォルダ内の動画ファイルをLosslessCutで複数起動するスクリプト。

- 複数の動画フォーマットに対応（mp4 / mov / avi / mkv / webm / m4v / mpg / mpeg / mxf / ts）
- 再帰的なファイル検索
- LosslessCutの複数インスタンス実行対応

```powershell
.\open-folder-videofiles-with-losslesscut.ps1
```

実行するとフォルダ選択ダイアログが表示されます。

## 前提条件

1. スクリプト先頭の `$losslessCutPath` を、ご利用環境の `LosslessCut.exe` のパスに合わせて変更してください。

   ```powershell
   $losslessCutPath = "C:\Program Files\LossLessCut\LosslessCut-win-x64\LosslessCut.exe"
   ```

2. LosslessCutの設定で「同時に複数のLosslessCutのインスタンスを実行するか（実験的）」を有効にしてください。
   この設定により、複数の動画ファイルを同時に処理できます。

## 補足

- 詳細はファイル先頭のコメント（comment-based help）を参照してください。
