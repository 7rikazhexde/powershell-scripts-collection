<#
.SYNOPSIS
WSLのホームディレクトリをエクスプローラーで開くシンプルなツール

.DESCRIPTION
WSL（Windows Subsystem for Linux）の指定されたディレクトリを
Windows Explorerで開くためのシンプルなスクリプトです。
ターゲットフォルダを指定しない場合はホームディレクトリを開きます。

.PARAMETER TargetFolder
開きたいフォルダのパス（オプション）。
WSLのホームディレクトリからの相対パスを指定します。

.NOTES
ファイル名: open-explorer-wsl.ps1
作成者: 7rikazhexde
作成日: 2024/12/26
バージョン: 0.1.0

このスクリプトはUTF-8 エンコーディング（BOMなし）で保存してください。

.EXAMPLE
.\open-explorer-wsl.ps1
WSLのホームディレクトリを開きます。

.EXAMPLE
.\open-explorer-wsl.ps1 -TargetFolder "dev/projects"
WSLのホームディレクトリ配下のdev/projectsフォルダを開きます。
#>

# パラメータの定義
param(
    [string]$TargetFolder = ""
)

$wslPath = "\\wsl.localhost\Ubuntu"
$fullPath = if ($TargetFolder) {
    Join-Path $wslPath $TargetFolder
} else {
    $wslPath
}

Start-Process explorer.exe -ArgumentList $fullPath
