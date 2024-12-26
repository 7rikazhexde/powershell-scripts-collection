<#
.SYNOPSIS
PowerShellスクリプト（.ps1）用のショートカット作成GUIツール

.DESCRIPTION
このスクリプトはPowerShellスクリプト（.ps1）のショートカットを作成するためのGUIツールです。
以下の機能を提供します：
- GUIによるps1ファイルの選択
- 選択したスクリプトと同じディレクトリにショートカットを作成
- ショートカット作成後の設定ガイド表示
- 作成したショートカットの保存先を直接開く機能

.PARAMETER Debug
デバッグモードを有効にします。
操作時の詳細なログが表示されます。

.NOTES
ファイル名: create-ps1-shortcut.ps1
作成者: 7rikazhexde
作成日: 2024/01/01
バージョン: 0.1

このスクリプトはUTF-8 with BOM エンコーディングで保存してください。

実行時の注意事項：
1. ショートカットをタスクバーにピン留めする場合:
   その他のオプションを確認 > タスクバーにピン留めする(K)

2. 実行ポリシーや引数を個別に指定する場合:
   プロパティ > ショートカット > リンク先

.EXAMPLE
.\create-ps1-shortcut.ps1
通常モードでGUIを起動し、ショートカットを作成します。

.EXAMPLE
.\create-ps1-shortcut.ps1 -Debug
デバッグモードでGUIを起動し、詳細な操作ログを表示します。
#>

# .NET Frameworkのクラスをロード
[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# CmdletBindingによって自動的に提供されるDebugパラメータを使用
if ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
    Write-Debug "デバッグモードが有効化されました"
}

function Show-FileDialog {
    [CmdletBinding()]
    param (
        [string]$Filter = "PowerShell Scripts (*.ps1)|*.ps1",
        [string]$Title = "Create Shortcut - Select PowerShell Script"
    )
    
    Write-Debug "ファイル選択ダイアログを表示: Title=$Title"
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = $Filter
    $dialog.Title = $Title
    
    Write-Debug "ダイアログを表示します"
    if ($dialog.ShowDialog() -eq 'OK') {
        Write-Debug "選択されたファイル: $($dialog.FileName)"
        return $dialog.FileName
    }
    Write-Debug "ファイル選択がキャンセルされました"
    return $null
}

function New-ScriptShortcut {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    Write-Debug "ショートカット作成を開始: ScriptPath=$ScriptPath"
    try {
        Write-Debug "WScript.Shellオブジェクトを作成"
        $WshShell = New-Object -ComObject WScript.Shell
        
        # ショートカットファイルのパスを設定
        $ShortcutPath = [System.IO.Path]::Combine(
            [System.IO.Path]::GetDirectoryName($ScriptPath),
            [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath) + "_shortcut.lnk"
        )
        Write-Debug "ショートカットパス: $ShortcutPath"
        
        # ショートカットオブジェクトを作成
        Write-Debug "ショートカットオブジェクトを作成"
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        
        # プロパティを設定
        Write-Debug "ショートカットのプロパティを設定"
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-File `"$ScriptPath`""
        $Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($ScriptPath)
        
        Write-Debug "ショートカットを保存"
        $Shortcut.Save()
        
        Write-Debug "ショートカット作成完了"
        return $ShortcutPath
    }
    catch {
        Write-Debug "エラーが発生: $($_.Exception.Message)"
        throw "ショートカットの作成に失敗しました: $_"
    }
}

function Show-CustomDialog {
    [CmdletBinding()]
    param (
        [string]$ShortcutPath
    )
    
    Write-Debug "カスタムダイアログを表示: ShortcutPath=$ShortcutPath"
    
    # WPFのXAML定義
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ショートカット作成完了" Height="250" Width="600"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="ショートカットを作成しました:" Margin="0,0,0,5"/>
        
        <TextBox Grid.Row="1" 
                 Text="$ShortcutPath" 
                 IsReadOnly="True"
                 FontFamily="Consolas"
                 Margin="0,0,0,10"
                 Padding="5"
                 Background="#F0F0F0"
                 TextWrapping="Wrap"/>

        <TextBlock Grid.Row="2" Margin="0,0,0,10">
            <Run Text="ショートカットをタスクバーから実行する場合は下記を設定してください。"/>
            <LineBreak/>
            <Run Text="その他のオプションを確認 > タスクバーにピン留めする(K)"/>
            <LineBreak/>
        </TextBlock>           
        
        <TextBlock Grid.Row="3" Margin="0,0,0,10">
            <Run Text="実行ポリシーや引数を個別に指定する場合は下記で設定を変更してください。"/>
            <LineBreak/>
            <Run Text="プロパティ > ショートカット > リンク先"/>
            <LineBreak/>
        </TextBlock>

        <StackPanel Grid.Row="4" 
                    Orientation="Horizontal" 
                    HorizontalAlignment="Center">
            <Button Name="OpenFolderButton" 
                    Content="保存先を開く" 
                    Width="100" 
                    Margin="5"/>
            <Button Name="CancelButton" 
                    Content="キャンセル" 
                    Width="100" 
                    Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

    Write-Debug "XAMLをロード"
    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    Write-Debug "ボタンコントロールを取得"
    $openFolderButton = $window.FindName("OpenFolderButton")
    $cancelButton = $window.FindName("CancelButton")

    Write-Debug "イベントハンドラを設定"
    $openFolderButton.Add_Click({
        Write-Debug "保存先を開くボタンがクリックされました"
        Start-Process "explorer.exe" -ArgumentList "/select,`"$ShortcutPath`""
        $window.Close()
    })

    $cancelButton.Add_Click({ 
        Write-Debug "キャンセルボタンがクリックされました"
        $window.Close() 
    })

    Write-Debug "ダイアログを表示"
    $window.ShowDialog() | Out-Null
    Write-Debug "ダイアログが閉じられました"
}

# メイン処理
function Main {
    [CmdletBinding()]
    param()

    Write-Debug "メイン処理を開始"
    
    # ファイル選択
    $scriptPath = Show-FileDialog
    Write-Debug "ファイル選択結果: $scriptPath"
    
    if ($scriptPath) {
        try {
            # ショートカット作成
            Write-Debug "ショートカット作成処理を開始"
            $shortcutPath = New-ScriptShortcut -ScriptPath $scriptPath
            Write-Debug "ショートカット作成完了: $shortcutPath"
            
            # カスタムダイアログを表示
            Write-Debug "完了ダイアログを表示"
            Show-CustomDialog -ShortcutPath $shortcutPath
        }
        catch {
            Write-Debug "エラーが発生: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show(
                $_.Exception.Message,
                "エラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    Write-Debug "メイン処理を終了"
}

# スクリプト実行
if ($PSBoundParameters['Debug']) {
    Write-Debug "スクリプトを開始"
    Main
    Write-Debug "スクリプトを終了"
} else {
    Main
}
