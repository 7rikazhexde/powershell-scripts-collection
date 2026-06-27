# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of standalone PowerShell scripts for simplifying Windows, Windows app, WSL (Windows Subsystem for Linux), and Claude Code operations. Each script is independent — there is no shared module, build step, or test suite. A script is "run," not "built."

Scripts are organized into topic subdirectories under `scripts/`:

- `scripts/folder/` — Explorer/folder operations (the WSL browser tools and the LosslessCut launcher).
- `scripts/powershell/` — PowerShell-related utilities (the .ps1 shortcut creator).
- `scripts/claudecode/` — Claude Code authoring helpers (e.g. installing skills).

## Running scripts

```powershell
# Normal run
.\scripts\folder\open-explorer-wsl-folder-action.ps1

# Debug run (verbose Write-Debug output) — supported by scripts using [CmdletBinding()]
.\scripts\folder\open-explorer-wsl-folder-action.ps1 -Debug
```

Execution requires an appropriate execution policy. Prefer process-scoped (non-persistent):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

PowerShell Core (`pwsh`, 7+) is the preferred runtime; scripts fall back to Windows PowerShell 5.1 (`powershell.exe`) where relevant. VSCode is configured to use `C:\Program Files\PowerShell\7\pwsh.exe`.

## Conventions

These patterns are shared across the original GUI scripts and should be preserved when editing them. (Smaller utility scripts such as `scripts/claudecode/Install-Skill.ps1` use a lighter style — a one-line usage comment and plain `param()` instead of the full help block — which is fine for non-GUI helpers.)

- **Comment-based help header.** Every script opens with a `<# .SYNOPSIS / .DESCRIPTION / .PARAMETER / .NOTES / .EXAMPLE #>` block. `.NOTES` carries `ファイル名` (filename), `作成者` (author: 7rikazhexde), `作成日` (creation date), `バージョン` (version), and the required save encoding — bump the version and update notes when changing a script's behavior.
- **File encoding matters and is declared per script.** GUI scripts (WPF/WinForms, with Japanese in XAML) must be saved as **UTF-8 with BOM**; the plain `open-explorer-wsl.ps1` is **UTF-8 without BOM**. Saving a BOM-required script without a BOM corrupts the Japanese UI text. Honor the encoding stated in each file's `.NOTES`.
- **Debug pattern.** Use `[CmdletBinding()] param()`, then `if ($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }`, and instrument with `Write-Debug`. The `-Debug` switch is provided automatically by `CmdletBinding`, not declared manually.
- **Output suppression.** `open-explorer-wsl-folder-action.ps1` wraps WPF calls that return values (e.g. `.Items.Add`, `.ShowDialog`) in `Write-SuppressedOutput` so they don't leak to the pipeline unless debugging.
- **Language split.** Code comments, UI strings, and docs are written in Japanese; identifiers and PowerShell idioms are English.

## GUI script structure

The WPF scripts (`open-explorer-wsl-folder-action.ps1`, `create-ps1-shortcut.ps1`) follow one pattern:

1. `Add-Type -AssemblyName PresentationFramework` (and `System.Windows.Forms` when file dialogs are used).
2. Define the UI as an inline XAML here-string (`@"..."@`); interpolate dynamic values directly into the XAML.
3. Load with `[Windows.Markup.XamlReader]::Load(...)`, then resolve controls via `$window.FindName("...")`.
4. Wire `Add_Click` / `Add_MouseDoubleClick` handlers; surface errors to the user with `[System.Windows.MessageBox]::Show(...)`.

## WSL path handling

WSL scripts target the `\\wsl.localhost\Ubuntu` UNC root. The "open in VSCode" action converts a Windows UNC path back to a WSL path before launching (`-replace '\\\\wsl\.localhost\\Ubuntu', ''` then `-replace '\\', '/'`) and runs `wsl code <path>`. The "up" navigation guards against escaping above the `\\wsl.localhost\Ubuntu` root.

## Claude Code skill installer

`scripts/claudecode/Install-Skill.ps1 -Name "<skill-name>"` installs a Claude Code skill by copying `~/Documents/import_skills/<Name>/SKILL.md` into `~/.claude/skills/<Name>/SKILL.md` (creating the destination directory). It then prints the first 5 lines of the copied file for verification and emits a template `Add-Content` snippet for registering the skill's trigger in `~/.claude/CLAUDE.md`. The append step is intentionally **not** automated — the printed template is meant to be reviewed and edited before being run by hand.

## Environment-specific paths

`open-folder-videofiles-with-losslesscut.ps1` hard-codes `$losslessCutPath` (the LosslessCut.exe location) at the top of the file and `Test-Path`-guards it. This is intentionally machine-specific — point users to edit that variable rather than committing a different absolute path.
