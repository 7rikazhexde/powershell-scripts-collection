<#
.SYNOPSIS
選択したフォルダ内の動画ファイルをLosslessCutで複数起動するスクリプト

.DESCRIPTION
このスクリプトは、ユーザーが選択したフォルダ内の動画ファイルを検索し、
それぞれのファイルに対してLosslessCutを起動します。
サポートされている動画フォーマットのファイルを再帰的に検索します。

.NOTES
ファイル名: open-folder-videofiles-with-losslesscut.ps1
作成者: 7rikazhexde
作成日: 2024/08/17
バージョン: 0.1.0

このスクリプトはUTF-8 with BOM エンコーディングで保存してください。

重要な設定と前提条件:
1. LosslessCut の設定から「同時に複数の LosslessCut のインスタンスを実行するか (実験的)」を有効にしてください。
   この設定により、複数の動画ファイルを同時に処理できるようになります。
   
2. スクリプトの先頭で $losslessCutPath 変数を定義し、LosslessCut.exe の正確なパスを指定してください。
   例: $losslessCutPath = "C:\Program Files\LossLessCut\LosslessCut-win-x64\LosslessCut.exe"

3. スクリプト実行権限の設定:
   このスクリプトを実行するには、適切な実行ポリシーを設定する必要があります。
   以下のいずれかの方法で設定してください：

   a) 一時的に現在のセッションの実行ポリシーを変更する（管理者権限が必要）:
      PowerShellを管理者として開き、以下のコマンドを実行します。
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

   b) スクリプトに対して個別に実行を許可する:
      PowerShellを開き、スクリプトのあるディレクトリに移動して以下のコマンドを実行します。
      Unblock-File -Path .\open-folder-videofiles-with-losslesscut.ps1

   c) システム全体の実行ポリシーを変更する（推奨されません）:
      PowerShellを管理者として開き、以下のコマンドを実行します。
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

   注意: セキュリティ上の理由から、信頼できるスクリプトのみを実行するようにしてください。

.EXAMPLE
.\ProcessVideosWithLosslessCut.ps1

.PARAMETER なし
このスクリプトにはパラメータはありません。実行時にフォルダ選択GUIが表示されます。
#>

# LosslessCut.exeのパスを定義
# 重要: このパスを環境に合わせて変更してください
$losslessCutPath = "C:\Program Files\LossLessCut\LosslessCut-win-x64\LosslessCut.exe"

# パスが正しいか確認
if (-not (Test-Path $losslessCutPath)) {
    Write-Host "エラー: LosslessCut.exe が指定されたパスに見つかりません。パスを確認してください。" -ForegroundColor Red
    Exit
}

# フォルダ選択用のGUIを表示
$folderBrowser = New-Object -ComObject Shell.Application
$selectedFolder = $folderBrowser.BrowseForFolder(0, "動画が格納されたフォルダを選択してください", 0)

# サポートする動画ファイル拡張子のリスト
$supportedExtensions = @("*.mp4", "*.mov", "*.avi", "*.mkv", "*.webm", "*.m4v", "*.mpg", "*.mpeg", "*.mxf", "*.ts")

# フォルダが選択された場合、パスを取得して処理を続行
if ($selectedFolder) {
    $folderPath = $selectedFolder.Self.Path
    Write-Host "選択されたフォルダ: $folderPath"
    
    # サブフォルダを含めて検索
    $videoFiles = Get-ChildItem -Path $folderPath -Include $supportedExtensions -File -Recurse
    Write-Host "見つかった動画ファイル数: $($videoFiles.Count)"

    # 各ファイルの詳細情報を表示
    foreach ($file in $videoFiles) {
        Write-Host "ファイル: $($file.FullName)"
        Write-Host "  サイズ: $($file.Length) bytes"
        Write-Host "  最終更新日: $($file.LastWriteTime)"
    }

    foreach ($videoFile in $videoFiles) {
        Write-Host "処理中のファイル: $($videoFile.FullName)"
        try {
            Start-Process $losslessCutPath -ArgumentList "`"$($videoFile.FullName)`"" -ErrorAction Stop
            Write-Host "LosslessCutが正常に起動されました"
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "エラーが発生しました: $_"
        }
    }
} else {
    Write-Host "フォルダが選択されませんでした。"
}

Write-Host "スクリプトが完了しました。何かキーを押して終了してください。"
Read-Host
