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
  'Lenovo Vantage -> System Update. BIOS capsules do NOT fit the 100 MB ESP: flash BIOS from USB (SETUP.md section 3a).'
  ''
  '-- apply --------------------------------'
  '  everything : upall'
  '  winget     : winget upgrade --all'
  '  npm -g     : npm update -g'
  '  (then: reboot)'
}
function upall {
  $sep = '-' * 41
  $sep; '> restore point (UAC)'
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -Command Checkpoint-Computer -Description ''machine-setup: upall'' -RestorePointType MODIFY_SETTINGS'
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
