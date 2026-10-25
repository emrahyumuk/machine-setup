# PowerShell 7 profile - Windows counterpart of dotfiles/zshrc.
# Installed to $PROFILE (with OneDrive Known Folder Move that is
# ~\OneDrive\<Documents>\PowerShell\Microsoft.PowerShell_profile.ps1).

# PATH - ~/.local/bin first (claude, machine-verify)
$env:Path = "$HOME\.local\bin;$env:Path"
$env:EDITOR = 'nvim'; $env:VISUAL = 'nvim'

# Prompt & navigation
Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Suggestions (zsh-autosuggestions counterpart, built into PSReadLine)
# (guarded: PSReadLine refuses predictions when output is redirected, e.g. agent shells)
if (-not [Console]::IsOutputRedirected) {
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
}
Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 100000
# Shift+Enter = new line, as in Ghostty on Fedora. Windows Terminal sends
# Shift+Enter as ESC CR (settings.json sendInput) so TUI apps like Claude
# Code see a distinct key; PSReadLine reads that as Alt+Enter.
Set-PSReadLineKeyHandler -Chord 'Shift+Enter' -Function AddLine
Set-PSReadLineKeyHandler -Chord 'Alt+Enter' -Function AddLine

# fzf: Ctrl+T file picker (Ctrl+R stays with atuin)
if (Get-Module -ListAvailable PSFzf) {
  Import-Module PSFzf
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
}

# Aliases - PowerShell ships built-in aliases for ls/cat/... that must go first
foreach ($a in 'ls','cat','tree') { Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue }
function ls   { eza --icons @args }
function ll   { eza -la --icons --git @args }
function tree { eza --tree --icons @args }
function cat  { bat --paging=never @args }
function df   { duf @args }
function lg   { lazygit @args }
function top  { btop4win @args }
Set-Alias vim nvim

# atuin (Ctrl+R history search) - last, it rebinds Ctrl+R
if (Get-Command atuin -ErrorAction SilentlyContinue) {
  Invoke-Expression (atuin init powershell --disable-up-arrow | Out-String)
}

# Update ritual (see machine-setup SETUP.md section 2b "Update cadence")
function upcheck {
  Write-Host '== winget (apps + Store) =='
  winget upgrade --include-unknown --accept-source-agreements --disable-interactivity
  Write-Host '== npm -g =='
  npm outdated -g
  Write-Host '== Windows Update =='
  try {
    $r = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    if ($r.Updates.Count) { $r.Updates | ForEach-Object { "  $($_.Title)" } } else { 'none' }
  } catch { "check FAILED: $($_.Exception.Message)" }
  Write-Host '== firmware =='
  'Lenovo Vantage -> System Update. BIOS: plug in a FAT32 USB key (>=128 MB free) BEFORE running the Windows updater - the capsule does not fit the 100 MB ESP and is staged on the key (SETUP.md section 3a).'
  ''
  '-- apply --------------------------------'
  '  everything : upall'
  '  winget     : winget upgrade --all'
  '  npm -g     : npm update -g'
  '  (then: reboot)'
}
# Restore point in an elevated Windows PowerShell (UAC). Returns 0 = a NEW point,
# 2 = none made (Windows allows one per 24 h by default), 1 = failed / UAC declined.
function New-MachineRestorePoint([string]$desc) {
  $s = @'
$ErrorActionPreference = 'Stop'
try {
  $b = (Get-ComputerRestorePoint | Measure-Object SequenceNumber -Maximum).Maximum
  Checkpoint-Computer -Description 'DESC' -RestorePointType MODIFY_SETTINGS -WarningAction SilentlyContinue
  $a = (Get-ComputerRestorePoint | Measure-Object SequenceNumber -Maximum).Maximum
  if ($a -gt $b) { exit 0 } else { exit 2 }
} catch { Write-Host "restore point FAILED: $_"; Start-Sleep 5; exit 1 }
'@ -replace 'DESC', $desc
  $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s))
  try {
    $p = Start-Process powershell.exe -Verb RunAs -PassThru -ErrorAction Stop -ArgumentList "-NoProfile -EncodedCommand $enc"
    $null = $p.Handle; $p.WaitForExit(); $p.ExitCode
  } catch { 1 }
}
function upall {
  $sep = '-' * 41
  $sep; '> restore point (UAC)'
  $rc = New-MachineRestorePoint 'machine-setup: upall'
  if ($rc -ne 0) {
    Write-Warning $(if ($rc -eq 2) { 'no NEW restore point: Windows allows one per 24 h by default (the last one is less than a day old)' } else { 'restore point FAILED or UAC was declined' })
    if ((Read-Host 'run winget upgrade --all WITHOUT a new undo point? [y/N]') -notmatch '^(y|yes)$') { 'stopped - nothing upgraded'; return }
  }
  $sep; '> winget - apps (Node is pinned to 24.*)'
  winget upgrade --all --accept-package-agreements --accept-source-agreements
  $sep; '> npm -g'
  npm update -g
  $sep; '> Windows Update - opening Settings'
  Start-Process 'ms-settings:windowsupdate-action'
  $sep
  '>> done - reboot after Windows Update finishes'
  if (Test-Path "$HOME\.local\bin\machine-verify.ps1") { $sep; machine-verify }
}
function machine-verify { & "$HOME\.local\bin\machine-verify.ps1" @args }
