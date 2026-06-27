<#
.SYNOPSIS
WSLのフォルダ操作用GUIツール

.DESCRIPTION
WSL（Windows Subsystem for Linux）のフォルダ構造をGUI(WPF)で表示し、以下の機能をサポートします。
 - フォルダのブラウズと移動
 - エクスプローラーでフォルダを開く
 - WSL上のVSCodeでフォルダを開く
 - 上位フォルダへの移動
 - フォルダの昇順・降順表示

.PARAMETER Debug
デバッグモードを有効にします。操作時の詳細な出力が表示されます。

.NOTES
ファイル名: open-explorer-wsl-folder-action.ps1
作成者: 7rikazhexde
作成日: 2024/12/26
バージョン: 0.1.1

1) このスクリプトはUTF-8 with BOM エンコーディングで保存してください。
2) タスクバーからの実行設定：
   - ショートカットを作成し、以下を設定
     powershell.exe -File "C:\path\to\open-explorer-wsl-folder-action.ps1"
   - タスクバーにピン留めする

.EXAMPLE
.\open-explorer-wsl-folder-action.ps1
通常モードで実行します。

.EXAMPLE
.\open-explorer-wsl-folder-action.ps1 -Debug
デバッグモードで実行し、詳細な操作ログを表示します。
#>

[CmdletBinding()]
param()

# .NET Frameworkのクラスをロード
Add-Type -AssemblyName PresentationFramework

# CmdletBindingによって自動的に提供されるDebugパラメータを使用
if ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
    Write-Debug "デバッグモードが有効化されました"
}

# デバッグ出力制御関数
function Write-SuppressedOutput {
    param($expression)
    if ($DebugPreference -eq 'Continue') {
        if ($expression -is [ScriptBlock]) {
            Write-Debug "Executing ScriptBlock"
            return $expression.Invoke()
        } else {
            Write-Debug "Executing operation"
            return $expression
        }
    } else {
        return [void]$expression
    }
}

# 初期フォルダ
$currentPath = "\\wsl.localhost\Ubuntu\home"
Write-Debug "Initial Path: $currentPath"

# WPFのXAML定義
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WSL フォルダブラウザ" Height="500" Width="600">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,5">
            <TextBlock Text="デフォルトパス：" Margin="0,0,10,0"/>
            <RadioButton Name="AscendingSort" Content="昇順" IsChecked="True" Margin="0,0,10,0"/>
            <RadioButton Name="DescendingSort" Content="降順"/>
        </StackPanel>
        <TextBox Name="DefaultPathBox" Grid.Row="1" Margin="0,0,0,10" Height="25"/>
        <ListBox Name="FolderList" Grid.Row="2" Margin="0,0,0,10"/>
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center">
            <Button Name="UpButton" Content="上へ移動" Width="100" Margin="5"/>
            <Button Name="OpenButton" Content="フォルダを開く" Width="100" Margin="5"/>
            <Button Name="VSCodeButton" Content="VSCodeで起動" Width="100" Margin="5"/>
            <Button Name="CancelButton" Content="キャンセル" Width="100" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

Write-Debug "Loading XAML..."
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
$reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# コントロールを取得
$defaultPathBox = $window.FindName("DefaultPathBox")
$folderList = $window.FindName("FolderList")
$upButton = $window.FindName("UpButton")
$openButton = $window.FindName("OpenButton")
$vscodeButton = $window.FindName("VSCodeButton")
$cancelButton = $window.FindName("CancelButton")
$ascendingSort = $window.FindName("AscendingSort")
$descendingSort = $window.FindName("DescendingSort")

Write-Debug "Controls loaded successfully"

# デフォルトパスを設定
$defaultPathBox.Text = $currentPath

# フォルダ一覧を更新する関数
function UpdateFolderList {
    param ($path)
    Write-Debug "Updating folder list for path: $path"
    
    Write-SuppressedOutput $folderList.Items.Clear()

    try {
        # 昇順・降順の設定に基づいてソート
        if ($ascendingSort.IsChecked) {
            $folders = Get-ChildItem -Path $path -Directory | Sort-Object Name
            Write-Debug "Sorting folders in ascending order"
        } else {
            $folders = Get-ChildItem -Path $path -Directory | Sort-Object Name -Descending
            Write-Debug "Sorting folders in descending order"
        }
        Write-Debug "Found $($folders.Count) folders"
        
        foreach ($folder in $folders) {
            $item = New-Object PSObject -Property @{
                Name = $folder.Name
                FullPath = $folder.FullName
            }
            Write-SuppressedOutput $folderList.Items.Add($item)
            Write-Debug "Added folder: $($folder.Name)"
        }
    } catch {
        Write-Debug "Error occurred while getting folders: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("フォルダを取得できません: $($_.Exception.Message)", "エラー", "OK", "Error")
    }
}

# ListBoxの表示形式を設定
Write-Debug "Configuring ListBox display settings"
$folderList.DisplayMemberPath = "Name"
$folderList.SelectedValuePath = "FullPath"

# 初期状態を設定
Write-Debug "Setting initial folder list"
Write-SuppressedOutput (UpdateFolderList $currentPath)

# イベントハンドラ: 上へ移動
$upButton.Add_Click({
    Write-Debug "Up button clicked"
    $parentPath = [System.IO.Directory]::GetParent($defaultPathBox.Text)
    if ($parentPath -and $parentPath.FullName -match "^\\\\wsl\.localhost\\Ubuntu") {
        Write-Debug "Moving to parent folder: $($parentPath.FullName)"
        $defaultPathBox.Text = $parentPath.FullName
        Write-SuppressedOutput (UpdateFolderList $parentPath.FullName)
    } else {
        Write-Debug "Cannot move up further"
        [System.Windows.MessageBox]::Show("これ以上上のフォルダには移動できません。", "情報", "OK", "Information")
    }
})

# イベントハンドラ: フォルダを開く
$openButton.Add_Click({
    Write-Debug "Open button clicked"
    $selectedItem = $folderList.SelectedItem
    if ($selectedItem) {
        Write-Debug "Opening folder: $($selectedItem.FullPath)"
        Start-Process explorer.exe -ArgumentList $selectedItem.FullPath
    } else {
        Write-Debug "No folder selected"
        [System.Windows.MessageBox]::Show("フォルダが選択されていません。", "情報", "OK", "Information")
    }
})

<#
# イベントハンドラ: WindowsのVSCodeで起動
$vscodeButton.Add_Click({
    Write-Debug "VSCode button clicked"
    $selectedItem = $folderList.SelectedItem
    if ($selectedItem) {
        Write-Debug "Opening VSCode for path: $($selectedItem.FullPath)"
        Start-Process code -ArgumentList $selectedItem.FullPath
    } else {
        Write-Debug "No folder selected"
        [System.Windows.MessageBox]::Show("フォルダが選択されていません。", "情報", "OK", "Information")
    }
})
#>

# イベントハンドラ: WSL2のVSCodeで起動
$vscodeButton.Add_Click({
    Write-Debug "VSCode button clicked"
    $selectedItem = $folderList.SelectedItem
    if ($selectedItem) {
        Write-Debug "Opening VSCode in WSL for path: $($selectedItem.FullPath)"
        # Windowsパスを WSL パスに変換して実行
        $wslPath = $selectedItem.FullPath -replace '\\\\wsl\.localhost\\Ubuntu', ''
        $wslPath = $wslPath -replace '\\', '/'
        Start-Process wsl -ArgumentList "code $wslPath"
    } else {
        Write-Debug "No folder selected"
        [System.Windows.MessageBox]::Show("フォルダが選択されていません。", "情報", "OK", "Information")
    }
})

# イベントハンドラ: キャンセル
$cancelButton.Add_Click({ 
    Write-Debug "Cancel button clicked"
    $window.Close() 
})

# イベントハンドラ: ソート順変更時に一覧を更新
$ascendingSort.Add_Checked({
    Write-Debug "Sort order changed to ascending"
    Write-SuppressedOutput (UpdateFolderList $defaultPathBox.Text)
})

$descendingSort.Add_Checked({
    Write-Debug "Sort order changed to descending"
    Write-SuppressedOutput (UpdateFolderList $defaultPathBox.Text)
})

# イベントハンドラ: フォルダをダブルクリックした場合に移動
$folderList.Add_MouseDoubleClick({
    Write-Debug "Folder double-clicked"
    $selectedItem = $folderList.SelectedItem
    if ($selectedItem) {
        Write-Debug "Moving to folder: $($selectedItem.FullPath)"
        $defaultPathBox.Text = $selectedItem.FullPath
        Write-SuppressedOutput (UpdateFolderList $selectedItem.FullPath)
    }
})

Write-Debug "Starting GUI..."
# ウィンドウを表示
Write-SuppressedOutput $window.ShowDialog()
