#requires -Version 5.1
<#
.SYNOPSIS
    Drag & drop video re-encoder GUI (ffmpeg front-end).

.DESCRIPTION
    Re-encodes videos into a uniform, high-quality H.264/H.265 MP4 to fix the
    playback stutter/skip that happens when concatenated clips have mismatched
    codecs, pixel formats, or (most often) variable frame rate (VFR).

    Two modes:
      - Re-encode each dropped file individually (default). Fixes a single
        already-merged file, or normalizes each clip on its own.
      - Normalize all dropped files and concat them into one output. This is
        the proper fix when the clips themselves differ (resolution/fps/codec).

    Quality is preserved via CRF (constant quality) on CPU, or the nearest
    hardware equivalent (CQ/global_quality/QP) on GPU. Resolution is kept as-is
    in individual mode, so there is no downscaling / no size reduction target.

    At startup the script probes ffmpeg for working GPU encoders (NVIDIA NVENC,
    Intel QSV, AMD AMF) by running a tiny throwaway encode for each. Only
    encoders that actually initialize on this machine are offered in the
    "エンコーダ" dropdown, defaulting to the fastest available GPU option.

.NOTES
    ファイル名: VideoReencoder.ps1
    作成者: 7rikazhexde
    作成日: 2026-07-08
    バージョン: 0.2.0
    - Run with Windows PowerShell 5.1 (STA). The script relaunches itself in STA
      automatically if needed.
    - Do NOT run elevated (as Administrator): drag & drop from Explorer into an
      elevated window is blocked by Windows (UIPI).
    - Requires ffmpeg (and ffprobe for progress %). Put them in PATH, or drop
      ffmpeg.exe / ffprobe.exe next to this script.
    - GPU encoding is encode-side only (decode stays on CPU); this keeps format
      handling simple and robust across mixed source codecs while still cutting
      encode time significantly versus libx264/libx265 on most footage.
    - Save as UTF-8 with BOM (Japanese UI strings in WinForms controls).
#>

# Resolve this script's own path (needed for the STA relaunch). $PSCommandPath
# can be empty depending on how the script is launched, so fall back.
$scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }

# --- Ensure STA apartment: WinForms drag & drop requires an STA thread.
#     Windows PowerShell 5.1 is STA by default; PowerShell 7 (pwsh) is MTA,
#     so relaunch under Windows PowerShell in STA when needed. The relaunch is
#     NOT hidden, so if the child fails to start its console stays visible. ---
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`""
    )
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Hide the owning console window. Called just before the form is shown so that
# any earlier startup error remains visible / catchable instead of vanishing.
function Hide-Console {
    try {
        if (-not ('Native.Win' -as [type])) {
            Add-Type -Name Win -Namespace Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        }
        $h = [Native.Win]::GetConsoleWindow()
        if ($h -ne [IntPtr]::Zero) { [void][Native.Win]::ShowWindow($h, 0) } # 0 = SW_HIDE
    } catch { }
}

# Guard the whole GUI setup so a startup failure shows a dialog instead of the
# window closing instantly with no explanation.
try {

# ---------------------------------------------------------------------------
# Tool resolution
# ---------------------------------------------------------------------------
function Resolve-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $PSScriptRoot "$Name.exe"
    if (Test-Path $local) { return $local }
    return $null
}
$script:FFmpeg  = Resolve-Tool 'ffmpeg'
$script:FFprobe = Resolve-Tool 'ffprobe'

# ---------------------------------------------------------------------------
# GPU encoder detection
#
# ffmpeg -encoders only reports what the binary was *compiled* with, not what
# actually works on this machine (wrong vendor GPU, missing/old driver, etc.),
# so each compiled candidate is probed with a real 1-frame encode. Only
# encoders that succeed are offered in the UI.
# ---------------------------------------------------------------------------
function Get-CompiledEncoders {
    if (-not $script:FFmpeg) { return @() }
    try {
        $out = & $script:FFmpeg -hide_banner -encoders 2>$null
        return @($out | Select-String -Pattern '^\s*V[A-Z\.]{5}\s+(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    } catch { return @() }
}

function Test-HwEncoder {
    param([string]$EncoderName)
    try {
        & $script:FFmpeg -y -hide_banner -loglevel error -f lavfi -i 'color=c=black:s=256x256:d=0.1' `
            -pix_fmt yuv420p -frames:v 1 -c:v $EncoderName -f null - *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

$script:HwEncoders = @{}
if ($script:FFmpeg) {
    $compiled = Get-CompiledEncoders
    foreach ($e in @('h264_nvenc', 'hevc_nvenc', 'h264_qsv', 'hevc_qsv', 'h264_amf', 'hevc_amf')) {
        $script:HwEncoders[$e] = ($compiled -contains $e) -and (Test-HwEncoder $e)
    }
}
$script:FamilyAvailable = [ordered]@{
    NVENC = ($script:HwEncoders['h264_nvenc'] -or $script:HwEncoders['hevc_nvenc'])
    QSV   = ($script:HwEncoders['h264_qsv'] -or $script:HwEncoders['hevc_qsv'])
    AMF   = ($script:HwEncoders['h264_amf'] -or $script:HwEncoders['hevc_amf'])
}

function Get-EncoderName {
    # Map an encoder family + codec choice to the actual ffmpeg -c:v value.
    param([string]$Family, [bool]$IsH265)
    switch ($Family) {
        'NVENC' { return $(if ($IsH265) { 'hevc_nvenc' } else { 'h264_nvenc' }) }
        'QSV'   { return $(if ($IsH265) { 'hevc_qsv' } else { 'h264_qsv' }) }
        'AMF'   { return $(if ($IsH265) { 'hevc_amf' } else { 'h264_amf' }) }
        default { return $(if ($IsH265) { 'libx265' } else { 'libx264' }) }
    }
}

function Get-QualityArgs {
    # Build the quality/speed control args for the chosen encoder family.
    # CRF has no direct GPU equivalent, so each family maps the same 0-51-ish
    # scale and preset name onto its own constant-quality knob.
    param([string]$Family, [string]$Crf, [string]$Preset)
    switch ($Family) {
        'NVENC' {
            $nvPreset = switch ($Preset) {
                'veryfast' { 'p1' }
                'faster'   { 'p2' }
                'fast'     { 'p3' }
                'medium'   { 'p4' }
                'slow'     { 'p6' }
                'slower'   { 'p7' }
                default    { 'p4' }
            }
            return @('-rc:v', 'vbr', '-cq:v', $Crf, '-b:v', '0', '-preset:v', $nvPreset, '-tune:v', 'hq')
        }
        'QSV' {
            return @('-global_quality:v', $Crf, '-preset:v', $Preset)
        }
        'AMF' {
            $amfQuality = switch ($Preset) {
                'veryfast' { 'speed' }
                'faster'   { 'speed' }
                'fast'     { 'speed' }
                'medium'   { 'balanced' }
                'slow'     { 'quality' }
                'slower'   { 'quality' }
                default    { 'balanced' }
            }
            return @('-rc:v', 'cqp', '-qp_i', $Crf, '-qp_p', $Crf, '-qp_b', $Crf, '-quality:v', $amfQuality)
        }
        default {
            return @('-crf', $Crf, '-preset', $Preset)
        }
    }
}

# ---------------------------------------------------------------------------
# ffprobe helpers
# ---------------------------------------------------------------------------
function Get-Duration {
    # Return media duration in seconds, or 0 if unknown
    param([string]$Path)
    if (-not $script:FFprobe) { return 0.0 }
    try {
        $out = & $script:FFprobe -v error -show_entries format=duration -of csv=p=0 -- "$Path" 2>$null
        $val = 0.0
        if ([double]::TryParse(($out | Select-Object -First 1), [ref]$val)) { return $val }
    } catch { }
    return 0.0
}

function Get-Resolution {
    # Return @{ W = <int>; H = <int> } for the first video stream
    param([string]$Path)
    if (-not $script:FFprobe) { return @{ W = 0; H = 0 } }
    try {
        $out = & $script:FFprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -- "$Path" 2>$null
        if ("$out" -match '(\d+)x(\d+)') { return @{ W = [int]$Matches[1]; H = [int]$Matches[2] } }
    } catch { }
    return @{ W = 0; H = 0 }
}

# ---------------------------------------------------------------------------
# Argument building
# ---------------------------------------------------------------------------
function Join-Args {
    # Build a command line, quoting only tokens that contain whitespace.
    # Windows filenames cannot contain '"', so no quote-escaping is needed.
    param([string[]]$Tokens)
    ($Tokens | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }) -join ' '
}

function Build-IndividualArgs {
    param([string]$InPath, [string]$OutPath)
    $t = @('-y', '-hide_banner', '-i', $InPath, '-map', '0:v:0', '-map', '0:a?', '-c:v', $script:VCodec)
    $t += Get-QualityArgs -Family $script:EncFamily -Crf $script:Crf -Preset $script:Preset
    $t += @('-pix_fmt', 'yuv420p')
    # Force constant frame rate when a target fps is chosen; VFR is a common
    # cause of stutter, and CFR output plays back smoothly everywhere.
    if ($script:Fps -ne 'source') { $t += @('-r', $script:Fps, '-vsync', 'cfr') }
    if ($script:AudioCopy) { $t += @('-c:a', 'copy') } else { $t += @('-c:a', 'aac', '-b:a', '256k') }
    $t += @('-movflags', '+faststart', '-progress', $script:ProgressFile, '-nostats', $OutPath)
    return , $t
}

function Build-MergeArgs {
    param([string[]]$InPaths, [string]$OutPath, [int]$W, [int]$H, [string]$Fps)
    $t = @('-y', '-hide_banner')
    foreach ($p in $InPaths) { $t += @('-i', $p) }
    $n = $InPaths.Count
    $fc = ''
    $lab = ''
    for ($i = 0; $i -lt $n; $i++) {
        # Normalize every input to the same canvas (letterbox-pad, square pixels,
        # fixed fps, standard pixel format) so concat produces a seamless stream.
        $fc += "[$i`:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${Fps},format=yuv420p[v$i];"
        $lab += "[v$i][$i`:a]"
    }
    $fc += "${lab}concat=n=${n}:v=1:a=1[outv][outa]"
    $t += @('-filter_complex', $fc, '-map', '[outv]', '-map', '[outa]', '-c:v', $script:VCodec)
    $t += Get-QualityArgs -Family $script:EncFamily -Crf $script:Crf -Preset $script:Preset
    $t += @('-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart',
        '-progress', $script:ProgressFile, '-nostats', $OutPath)
    return , $t
}

function Get-UniqueOut {
    # Pick a non-colliding output path. $Reserved tracks paths already handed
    # out earlier in the same job-building pass (e.g. "clip.mp4" and "clip.mov"
    # in one drop both want "clip_reencoded.mp4"), since none of them exist on
    # disk yet at that point and Test-Path alone can't tell them apart.
    param([string]$Path, [System.Collections.Generic.HashSet[string]]$Reserved)
    $dir = Split-Path $Path -Parent
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [IO.Path]::GetExtension($Path)
    $candidate = $Path
    $i = 1
    while ((Test-Path $candidate) -or $Reserved.Contains($candidate.ToLowerInvariant())) {
        $candidate = Join-Path $dir ("{0}_{1}{2}" -f $name, $i, $ext)
        $i++
    }
    [void]$Reserved.Add($candidate.ToLowerInvariant())
    return $candidate
}

# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Video Re-encoder (ffmpeg)'
$form.Size = New-Object System.Drawing.Size(660, 674)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(660, 674)

$lblDrop = New-Object System.Windows.Forms.Label
$lblDrop.Text = 'ここに動画ファイルをドラッグ＆ドロップ（複数可）'
$lblDrop.Location = New-Object System.Drawing.Point(12, 10)
$lblDrop.AutoSize = $true
$form.Controls.Add($lblDrop)

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(12, 32)
$lstFiles.Size = New-Object System.Drawing.Size(520, 150)
$lstFiles.SelectionMode = 'MultiExtended'
$lstFiles.AllowDrop = $true
$lstFiles.HorizontalScrollbar = $true
$lstFiles.Anchor = 'Top,Left,Right'
$form.Controls.Add($lstFiles)

# Drag & drop wiring (both the list and the form accept drops)
$dragEnter = {
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    }
}
$dragDrop = {
    param($s, $e)
    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    foreach ($f in $files) {
        if ((Test-Path $f -PathType Leaf) -and -not $lstFiles.Items.Contains($f)) {
            [void]$lstFiles.Items.Add($f)
        }
    }
}
$lstFiles.Add_DragEnter($dragEnter); $lstFiles.Add_DragDrop($dragDrop)
$form.AllowDrop = $true
$form.Add_DragEnter($dragEnter); $form.Add_DragDrop($dragDrop)

# File list buttons
$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = '追加...'; $btnAdd.Location = New-Object System.Drawing.Point(540, 32)
$btnAdd.Size = New-Object System.Drawing.Size(100, 28); $btnAdd.Anchor = 'Top,Right'
$form.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = '選択削除'; $btnRemove.Location = New-Object System.Drawing.Point(540, 66)
$btnRemove.Size = New-Object System.Drawing.Size(100, 28); $btnRemove.Anchor = 'Top,Right'
$form.Controls.Add($btnRemove)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = '全消去'; $btnClear.Location = New-Object System.Drawing.Point(540, 100)
$btnClear.Size = New-Object System.Drawing.Size(100, 28); $btnClear.Anchor = 'Top,Right'
$form.Controls.Add($btnClear)

$btnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Filter = '動画ファイル|*.mp4;*.mov;*.mkv;*.avi;*.m4v;*.ts;*.webm;*.flv;*.wmv|すべて|*.*'
    if ($dlg.ShowDialog() -eq 'OK') {
        foreach ($f in $dlg.FileNames) { if (-not $lstFiles.Items.Contains($f)) { [void]$lstFiles.Items.Add($f) } }
    }
})
$btnRemove.Add_Click({
    foreach ($i in @($lstFiles.SelectedIndices | Sort-Object -Descending)) { $lstFiles.Items.RemoveAt($i) }
})
$btnClear.Add_Click({ $lstFiles.Items.Clear() })

# Mode
$grpMode = New-Object System.Windows.Forms.GroupBox
$grpMode.Text = '処理モード'; $grpMode.Location = New-Object System.Drawing.Point(12, 192)
$grpMode.Size = New-Object System.Drawing.Size(628, 52); $grpMode.Anchor = 'Top,Left,Right'
$form.Controls.Add($grpMode)

$rbEach = New-Object System.Windows.Forms.RadioButton
$rbEach.Text = '個別に再エンコード（1ファイルずつ）'; $rbEach.Location = New-Object System.Drawing.Point(14, 20)
$rbEach.Size = New-Object System.Drawing.Size(280, 24); $rbEach.Checked = $true
$grpMode.Controls.Add($rbEach)

$rbMerge = New-Object System.Windows.Forms.RadioButton
$rbMerge.Text = '正規化して1本に結合（複数→1）'; $rbMerge.Location = New-Object System.Drawing.Point(310, 20)
$rbMerge.Size = New-Object System.Drawing.Size(300, 24)
$grpMode.Controls.Add($rbMerge)

# Settings row helpers
function New-Label($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, ($y + 3)); $l.AutoSize = $true
    $form.Controls.Add($l); return $l
}
function New-Combo($x, $y, $w, $items, $default) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.Location = New-Object System.Drawing.Point($x, $y); $c.Width = $w
    $c.DropDownStyle = 'DropDownList'
    foreach ($i in $items) { [void]$c.Items.Add($i) }
    $c.SelectedItem = $default
    $form.Controls.Add($c); return $c
}

# Encoder family (CPU or whichever GPU accelerators actually work here)
$encoderItems = New-Object System.Collections.ArrayList
[void]$encoderItems.Add('CPU (libx264 / libx265)')
if ($script:FamilyAvailable.NVENC) { [void]$encoderItems.Add('GPU: NVIDIA NVENC') }
if ($script:FamilyAvailable.QSV) { [void]$encoderItems.Add('GPU: Intel QSV') }
if ($script:FamilyAvailable.AMF) { [void]$encoderItems.Add('GPU: AMD AMF') }
$defaultEncoder =
    if ($script:FamilyAvailable.NVENC) { 'GPU: NVIDIA NVENC' }
    elseif ($script:FamilyAvailable.QSV) { 'GPU: Intel QSV' }
    elseif ($script:FamilyAvailable.AMF) { 'GPU: AMD AMF' }
    else { 'CPU (libx264 / libx265)' }

New-Label 'エンコーダ' 12 256 | Out-Null
$cmbEncoder = New-Combo 90 253 220 $encoderItems $defaultEncoder

New-Label 'コーデック' 12 290 | Out-Null
$cmbCodec = New-Combo 90 287 150 @('H.264 (libx264)', 'H.265 (libx265)') 'H.264 (libx264)'

New-Label '品質(CRF)' 260 290 | Out-Null
$cmbCrf = New-Combo 335 287 70 @('16', '18', '20', '23') '18'

New-Label 'プリセット' 425 290 | Out-Null
$cmbPreset = New-Combo 495 287 110 @('veryfast', 'faster', 'fast', 'medium', 'slow', 'slower') 'medium'

New-Label 'フレームレート' 12 324 | Out-Null
$cmbFps = New-Combo 90 321 150 @('元のまま', '24', '25', '30', '60') '元のまま'

New-Label '音声' 260 324 | Out-Null
$cmbAudio = New-Combo 335 321 270 @('AAC 256k で再エンコード', '元の音声をコピー') 'AAC 256k で再エンコード'

# Output folder
New-Label '出力先' 12 358 | Out-Null
$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(90, 355); $txtOut.Size = New-Object System.Drawing.Size(430, 24)
$txtOut.Anchor = 'Top,Left,Right'
$txtOut.Text = ''
$form.Controls.Add($txtOut)
$lblOutHint = New-Object System.Windows.Forms.Label
$lblOutHint.Text = '（空欄なら元ファイルと同じフォルダ）'
$lblOutHint.Location = New-Object System.Drawing.Point(90, 382); $lblOutHint.AutoSize = $true
$lblOutHint.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblOutHint)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '参照...'; $btnBrowse.Location = New-Object System.Drawing.Point(528, 354)
$btnBrowse.Size = New-Object System.Drawing.Size(112, 26); $btnBrowse.Anchor = 'Top,Right'
$form.Controls.Add($btnBrowse)
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fbd.ShowDialog() -eq 'OK') { $txtOut.Text = $fbd.SelectedPath }
})

# Progress
New-Label '現在のファイル' 12 406 | Out-Null
$pbCurrent = New-Object System.Windows.Forms.ProgressBar
$pbCurrent.Location = New-Object System.Drawing.Point(110, 404); $pbCurrent.Size = New-Object System.Drawing.Size(530, 20)
$pbCurrent.Anchor = 'Top,Left,Right'
$form.Controls.Add($pbCurrent)

New-Label '全体' 12 432 | Out-Null
$pbOverall = New-Object System.Windows.Forms.ProgressBar
$pbOverall.Location = New-Object System.Drawing.Point(110, 430); $pbOverall.Size = New-Object System.Drawing.Size(530, 20)
$pbOverall.Anchor = 'Top,Left,Right'
$form.Controls.Add($pbOverall)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = '待機中'
$lblStatus.Location = New-Object System.Drawing.Point(12, 456); $lblStatus.AutoSize = $true
$lblStatus.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblStatus)

# Log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(12, 480); $txtLog.Size = New-Object System.Drawing.Size(628, 108)
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true; $txtLog.ScrollBars = 'Vertical'
$txtLog.Anchor = 'Top,Bottom,Left,Right'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($txtLog)

# Run / Abort
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = '実行'; $btnRun.Location = New-Object System.Drawing.Point(430, 596)
$btnRun.Size = New-Object System.Drawing.Size(100, 34); $btnRun.Anchor = 'Bottom,Right'
$form.Controls.Add($btnRun)

$btnAbort = New-Object System.Windows.Forms.Button
$btnAbort.Text = '中止'; $btnAbort.Location = New-Object System.Drawing.Point(538, 596)
$btnAbort.Size = New-Object System.Drawing.Size(100, 34); $btnAbort.Anchor = 'Bottom,Right'; $btnAbort.Enabled = $false
$form.Controls.Add($btnAbort)

# ---------------------------------------------------------------------------
# Runtime state and encoding pipeline (driven by a UI-thread timer)
# ---------------------------------------------------------------------------
$script:jobs = @()
$script:jobIndex = 0
$script:totalDur = 0.0
$script:doneDur = 0.0
$script:proc = $null
$script:errEvent = $null
$script:errBuf = $null
$script:progressFile = $null
$script:aborted = $false
$script:okCount = 0
$script:failCount = 0

function Write-Log($msg) {
    $txtLog.AppendText(("{0}  {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $msg))
}

function Set-Status($text, $color) {
    $lblStatus.Text = $text
    if ($color) { $lblStatus.ForeColor = $color }
}

function Set-UIEnabled($enabled) {
    foreach ($c in @($lstFiles, $btnAdd, $btnRemove, $btnClear, $rbEach, $rbMerge,
            $cmbEncoder, $cmbCodec, $cmbCrf, $cmbPreset, $cmbFps, $cmbAudio, $txtOut, $btnBrowse, $btnRun)) {
        $c.Enabled = $enabled
    }
    $btnAbort.Enabled = -not $enabled
}

function Read-ProgressSeconds {
    # Parse the last out_time= value from ffmpeg's -progress file.
    # Open with shared read/write because ffmpeg is writing concurrently.
    param([string]$File)
    if (-not $File -or -not (Test-Path $File)) { return -1 }
    try {
        $fs = [System.IO.File]::Open($File, 'Open', 'Read', 'ReadWrite')
        $sr = New-Object System.IO.StreamReader($fs)
        $text = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    } catch { return -1 }
    $m = [regex]::Matches($text, 'out_time=(\d+):(\d+):(\d+(?:\.\d+)?)')
    if ($m.Count -gt 0) {
        $g = $m[$m.Count - 1].Groups
        return ([int]$g[1].Value * 3600) + ([int]$g[2].Value * 60) + [double]$g[3].Value
    }
    return -1
}

function Stop-CurrentProc {
    if ($script:errEvent) {
        Unregister-Event -SourceIdentifier $script:errEvent.Name -ErrorAction SilentlyContinue
        $script:errEvent = $null
    }
    if ($script:progressFile) { Remove-Item $script:progressFile -ErrorAction SilentlyContinue }
}

function Start-NextJob {
    $job = $script:jobs[$script:jobIndex]
    $script:progressFile = [System.IO.Path]::GetTempFileName()

    if ($job.Merge) {
        $tokens = Build-MergeArgs -InPaths $job.Ins -OutPath $job.Out -W $job.W -H $job.H -Fps $job.Fps
    } else {
        $tokens = Build-IndividualArgs -InPath $job.In -OutPath $job.Out
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:FFmpeg
    $psi.Arguments = Join-Args $tokens
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true   # must be drained to avoid deadlock

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $script:errBuf = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    [void]$proc.Start()
    $script:proc = $proc
    $script:errEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) { [void]$Event.MessageData.Add($EventArgs.Data) }
    } -MessageData $script:errBuf
    $proc.BeginErrorReadLine()

    $pbCurrent.Value = 0
    Write-Log ("▶ [{0}/{1}] {2}" -f ($script:jobIndex + 1), $script:jobs.Count, (Split-Path $job.Out -Leaf))
}

function Complete-Run {
    $script:proc = $null
    Set-UIEnabled $true

    if ($script:aborted) {
        Set-Status '■ 中止しました' ([System.Drawing.Color]::DarkOrange)
        return
    }

    $pbOverall.Value = 100
    $ok = $script:okCount
    $fail = $script:failCount

    if ($fail -eq 0) {
        Set-Status ("✔ すべて完了しました（成功 {0} 件）" -f $ok) ([System.Drawing.Color]::ForestGreen)
        [System.Media.SystemSounds]::Asterisk.Play()
        $icon = 'Information'
    } else {
        Set-Status ("⚠ 完了（成功 {0} 件 / 失敗 {1} 件）" -f $ok, $fail) ([System.Drawing.Color]::OrangeRed)
        [System.Media.SystemSounds]::Exclamation.Play()
        $icon = 'Warning'
    }

    # Summarize and offer to open the output folder
    $dirs = @($script:jobs | ForEach-Object { Split-Path $_.Out -Parent } | Select-Object -Unique)
    $dirText = if ($dirs.Count -eq 1) { $dirs[0] } else { '各元ファイルと同じフォルダ' }
    $msg = ("処理が完了しました。`n`n成功: {0} 件 / 失敗: {1} 件`n出力先: {2}`n`n出力フォルダを開きますか？" -f $ok, $fail, $dirText)
    $res = [System.Windows.Forms.MessageBox]::Show($msg, '完了', 'YesNo', $icon)
    if ($res -eq 'Yes' -and $dirs.Count -ge 1 -and (Test-Path $dirs[0])) {
        Start-Process explorer.exe $dirs[0]
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    if (-not $script:proc) { return }
    $job = $script:jobs[$script:jobIndex]

    # Update progress bars from the -progress file
    $cur = Read-ProgressSeconds $script:progressFile
    if ($job.Dur -gt 0 -and $cur -ge 0) {
        $pct = [Math]::Min(100, [int](($cur / $job.Dur) * 100))
        $pbCurrent.Value = $pct
        if ($script:totalDur -gt 0) {
            $pbOverall.Value = [Math]::Min(100, [int]((($script:doneDur + $cur) / $script:totalDur) * 100))
        }
        $lblStatus.Text = ("エンコード中: {0}  ({1}%)" -f (Split-Path $job.Out -Leaf), $pct)
    } else {
        $lblStatus.Text = ("エンコード中: {0}" -f (Split-Path $job.Out -Leaf))
    }

    if ($script:proc.HasExited) {
        $code = $script:proc.ExitCode
        Stop-CurrentProc
        if ($code -eq 0) {
            $pbCurrent.Value = 100
            $script:doneDur += $job.Dur
            $script:okCount++
            Write-Log ("✔ 完了: {0}" -f (Split-Path $job.Out -Leaf))
        } else {
            $script:failCount++
            Write-Log ("✗ 失敗 (exit={0}): {1}" -f $code, (Split-Path $job.In -Leaf))
            $tail = @($script:errBuf | Select-Object -Last 12)
            foreach ($line in $tail) { Write-Log ("    {0}" -f $line) }
        }
        $script:jobIndex++
        if (-not $script:aborted -and $script:jobIndex -lt $script:jobs.Count) {
            Start-NextJob
        } else {
            $timer.Stop()
            Complete-Run
        }
    }
})

$btnRun.Add_Click({
    if (-not $script:FFmpeg) {
        [System.Windows.Forms.MessageBox]::Show(
            'ffmpeg が見つかりません。PATH に通すか、ffmpeg.exe をこのスクリプトと同じフォルダに置いてください。',
            'エラー', 'OK', 'Error') | Out-Null
        return
    }
    $files = @($lstFiles.Items)
    if ($files.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('ファイルをドラッグ＆ドロップしてください。', '確認', 'OK', 'Information') | Out-Null
        return
    }
    if (-not $script:FFprobe) {
        Write-Log '※ ffprobe が無いため進捗%は表示されません（処理は実行されます）'
    }

    # Read settings
    $script:EncFamily = switch -Wildcard ($cmbEncoder.SelectedItem) {
        '*NVENC*' { 'NVENC' }
        '*QSV*'   { 'QSV' }
        '*AMF*'   { 'AMF' }
        default   { 'CPU' }
    }
    $isH265 = ($cmbCodec.SelectedItem -like 'H.265*')
    $script:VCodec = Get-EncoderName -Family $script:EncFamily -IsH265 $isH265
    if ($script:EncFamily -ne 'CPU' -and -not $script:HwEncoders[$script:VCodec]) {
        # Selected family/codec pair didn't pass the startup probe after all
        # (e.g. GPU driver only supports H.264, not H.265) — fail safe to CPU.
        Write-Log ("⚠ {0} は利用できないため CPU エンコードにフォールバックします" -f $script:VCodec)
        $script:EncFamily = 'CPU'
        $script:VCodec = Get-EncoderName -Family 'CPU' -IsH265 $isH265
    }
    $script:Crf = "$($cmbCrf.SelectedItem)"
    $script:Preset = "$($cmbPreset.SelectedItem)"
    $script:Fps = if ($cmbFps.SelectedItem -eq '元のまま') { 'source' } else { "$($cmbFps.SelectedItem)" }
    $script:AudioCopy = ($cmbAudio.SelectedItem -like '*コピー*')
    $outDir = $txtOut.Text.Trim()
    if ($outDir -and -not (Test-Path $outDir)) {
        [System.Windows.Forms.MessageBox]::Show('出力先フォルダが存在しません。', 'エラー', 'OK', 'Error') | Out-Null
        return
    }

    # Build job list
    $jobList = New-Object System.Collections.ArrayList
    $script:totalDur = 0.0; $script:doneDur = 0.0
    # Tracks output paths already handed out in this pass, so two inputs that
    # would compute the same "<basename>_reencoded.mp4" (same name, different
    # source folder or extension) don't collide before either file exists.
    $reservedOut = [System.Collections.Generic.HashSet[string]]::new()

    if ($rbMerge.Checked) {
        if ($files.Count -lt 2) {
            [System.Windows.Forms.MessageBox]::Show('結合には2つ以上のファイルが必要です。', '確認', 'OK', 'Information') | Out-Null
            return
        }
        $lblStatus.Text = '解析中...'; $form.Refresh()
        $W = 0; $H = 0; $dur = 0.0
        foreach ($f in $files) {
            $r = Get-Resolution $f
            if ($r.W -gt $W) { $W = $r.W }
            if ($r.H -gt $H) { $H = $r.H }
            $dur += (Get-Duration $f)
        }
        if ($W -le 0) { $W = 1920; $H = 1080 }
        if ($W % 2 -ne 0) { $W++ }
        if ($H % 2 -ne 0) { $H++ }
        $mfps = if ($script:Fps -eq 'source') { '30' } else { $script:Fps }
        $dir = if ($outDir) { $outDir } else { Split-Path $files[0] -Parent }
        $out = Get-UniqueOut (Join-Path $dir 'merged_reencoded.mp4') $reservedOut
        [void]$jobList.Add(@{ Merge = $true; Ins = $files; In = $files[0]; Out = $out; Dur = $dur; W = $W; H = $H; Fps = $mfps })
        $script:totalDur = $dur
        Write-Log ("結合設定: {0}x{1} / {2}fps / {3}本" -f $W, $H, $mfps, $files.Count)
    } else {
        foreach ($f in $files) {
            $d = Get-Duration $f
            $dir = if ($outDir) { $outDir } else { Split-Path $f -Parent }
            $base = [System.IO.Path]::GetFileNameWithoutExtension($f)
            $out = Get-UniqueOut (Join-Path $dir ("{0}_reencoded.mp4" -f $base)) $reservedOut
            [void]$jobList.Add(@{ Merge = $false; In = $f; Out = $out; Dur = $d })
            $script:totalDur += $d
        }
    }

    $script:jobs = $jobList.ToArray()
    $script:jobIndex = 0
    $script:aborted = $false
    $script:okCount = 0
    $script:failCount = 0
    $pbOverall.Value = 0
    Set-UIEnabled $false
    Set-Status '処理中...' ([System.Drawing.Color]::RoyalBlue)
    Write-Log ("=== 開始: {0} ジョブ / {1} [{2}] (preset={3}, quality={4}) ===" -f $script:jobs.Count, $script:VCodec, $script:EncFamily, $script:Preset, $script:Crf)
    Start-NextJob
    $timer.Start()
})

$btnAbort.Add_Click({
    $script:aborted = $true
    if ($script:proc -and -not $script:proc.HasExited) {
        try { $script:proc.Kill() } catch { }
    }
    $timer.Stop()
    Stop-CurrentProc
    Write-Log '■ 中止しました'
    Complete-Run
})

# Clean up on close
$form.Add_FormClosing({
    $timer.Stop()
    if ($script:proc -and -not $script:proc.HasExited) { try { $script:proc.Kill() } catch { } }
    Stop-CurrentProc
})

# Startup diagnostics
if ($script:FFmpeg) { Write-Log ("ffmpeg: {0}" -f $script:FFmpeg) } else { Write-Log '⚠ ffmpeg が見つかりません' }
if ($script:FFprobe) { Write-Log ("ffprobe: {0}" -f $script:FFprobe) } else { Write-Log '⚠ ffprobe が見つかりません（進捗%は非表示）' }
if ($script:FamilyAvailable.NVENC) { Write-Log 'GPU検出: NVIDIA NVENC が使用可能です' }
if ($script:FamilyAvailable.QSV) { Write-Log 'GPU検出: Intel QSV が使用可能です' }
if ($script:FamilyAvailable.AMF) { Write-Log 'GPU検出: AMD AMF が使用可能です' }
if (-not ($script:FamilyAvailable.NVENC -or $script:FamilyAvailable.QSV -or $script:FamilyAvailable.AMF)) {
    Write-Log '※ 使用可能なGPUエンコーダが見つかりませんでした（CPUエンコードのみ利用可能）'
}

Hide-Console
[void]$form.ShowDialog()
}
catch {
    $detail = "$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
    try {
        [System.Windows.Forms.MessageBox]::Show(
            "起動中にエラーが発生しました。`n`n$detail",
            'エラー', 'OK', 'Error') | Out-Null
    } catch {
        # Last-resort fallback if even the message box is unavailable
        Write-Host "起動エラー: $detail" -ForegroundColor Red
        Read-Host 'Enter キーで閉じます'
    }
}
