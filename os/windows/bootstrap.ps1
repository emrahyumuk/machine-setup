# bootstrap (Windows) - the judgment-free part of SETUP.md section 2b, written from
# the first Windows session (2026-10-24, thinkpad-p14s dual-boot slice).
# Run from the repo root in Windows PowerShell 5.1 or pwsh, NOT elevated:
#   powershell -ExecutionPolicy Bypass -File os\windows\bootstrap.ps1 [-System] [-Debloat] [-Rust]
# -System  : also the admin items (one UAC prompt): hibernation off, System
#            Protection on C: (5 GB cap) + a restore point.
# -Debloat : remove the Store apps the owner removed on 2026-10-24 (current user).
#            Needs Windows PowerShell 5.1 (powershell.exe): the Appx cmdlets are
#            not native in pwsh 7 - enforced below.
# -Rust    : [role: Windows release builds] rustup (minimal, msvc, sha256-checked)
#            + VS Build Tools C++ workload (UAC, ~6.5 GB) + the installer's
#            KeepDownloadedPayloads=0 policy (UAC). Smart App Control must be
#            turned OFF by hand to run local builds - a one-way switch, so never
#            scripted (section 2b).
# Overwrites its config files (the first run backs up WT/PowerToys/profile; a
# re-run keeps that first backup). Not covered (GUI or identity - see section 2b):
# Chrome/mpv defaults, Vantage charge threshold, git user.name/email, gh auth
# login, Windows Hello, BIOS.
param([switch]$System, [switch]$Debloat, [switch]$Rust)
$ErrorActionPreference = 'Stop'
if ($Debloat -and $PSVersionTable.PSEdition -ne 'Desktop') {
  throw '-Debloat needs Windows PowerShell 5.1: run  powershell -ExecutionPolicy Bypass -File os\windows\bootstrap.ps1 -Debloat  (not pwsh)'
}
$repo = Resolve-Path "$PSScriptRoot\..\.."
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
$failed = @()
# winget success: 0, or "already installed / no applicable upgrade"
# (0x8A15002B = -1978335189, 0x8A150061 = -1978335135)
$wingetOk = 0, -1978335189, -1978335135
# Runs a script block's text in an elevated Windows PowerShell (one UAC prompt)
# and returns its exit code; a declined UAC prompt or a lost handle returns 1.
function Invoke-Elevated([string]$script) {
  $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
  try {
    $p = Start-Process powershell.exe -Verb RunAs -PassThru -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
    $null = $p.Handle; $p.WaitForExit(); $p.ExitCode
  } catch { Write-Warning "elevated step not run: $($_.Exception.Message)"; 1 }
}

if ($System) {
  # exit 0 = done + a NEW restore point; 2 = done, but Windows made no new point
  # (one per 24 h by default); 1 = a step failed
  $rc = Invoke-Elevated @'
$ErrorActionPreference = 'Stop'
try {
  powercfg /h off
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
  Enable-ComputerRestore -Drive 'C:\'
  vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5GB
  $b = (Get-ComputerRestorePoint | Measure-Object SequenceNumber -Maximum).Maximum
  Checkpoint-Computer -Description 'machine-setup: bootstrap' -RestorePointType MODIFY_SETTINGS -WarningAction SilentlyContinue
  $a = (Get-ComputerRestorePoint | Measure-Object SequenceNumber -Maximum).Maximum
  if ($a -gt $b) { exit 0 } else { Write-Host 'no new restore point (one per 24 h limit?)'; Start-Sleep 5; exit 2 }
} catch { Write-Host "FAILED: $_"; Start-Sleep 10; exit 1 }
'@
  if ($rc -ne 0) {
    Write-Warning $(if ($rc -eq 2) { 'no NEW restore point (Windows allows one per 24 h by default)' } else { '-System step FAILED or UAC was declined - hibernation/System Protection may not be set, no restore point' })
    if ((Read-Host 'install packages WITHOUT a fresh undo point? [y/N]') -notmatch '^(y|yes)$') { 'stopped before any package install'; exit 1 }
  }
}

# --- packages (winget; first-party package manager - section 2b)
$ids = 'Git.Git','Microsoft.PowerShell','GitHub.cli','dandavison.delta','JesseDuffield.lazygit',
       'Starship.Starship','ajeetdsouza.zoxide','junegunn.fzf','Atuinsh.Atuin','eza-community.eza',
       'sharkdp.bat','muesli.duf','aristocratos.btop4win','Neovim.Neovim','DEVCOM.JetBrainsMonoNerdFont',
       'OpenJS.NodeJS.LTS','pnpm.pnpm','Microsoft.VisualStudioCode','shinchiro.mpv',
       'Mozilla.Thunderbird','Bitwarden.Bitwarden','Spotify.Spotify','Microsoft.PowerToys','Google.Chrome'
foreach ($i in $ids) {
  winget install --id $i --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
  $rc = $LASTEXITCODE
  if ($wingetOk -contains $rc) { "$i ok" } else { "$i FAILED exit=$rc"; $failed += "winget $i ($rc)" }
}
winget pin add --id OpenJS.NodeJS.LTS --version '24.*' --accept-source-agreements --disable-interactivity | Out-Null
Refresh-Path

if ($Rust) {
  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --accept-package-agreements --accept-source-agreements --disable-interactivity `
    --override '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
  if ($wingetOk -notcontains $LASTEXITCODE) { $failed += "winget Microsoft.VisualStudio.2022.BuildTools ($LASTEXITCODE)" }
  # the installer drops its payload cache itself from now on (section 2b: never
  # hand-delete C:\ProgramData\Microsoft\VisualStudio\Packages)
  $rc = Invoke-Elevated @'
$ErrorActionPreference = 'Stop'
try {
  New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\VisualStudio\Setup' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\VisualStudio\Setup' -Name KeepDownloadedPayloads -Value 0 -PropertyType DWord -Force | Out-Null
} catch { Write-Host "FAILED: $_"; Start-Sleep 10; exit 1 }
exit 0
'@
  if ($rc -ne 0) { $failed += 'KeepDownloadedPayloads=0 policy' }
  $base = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'
  $ri = Join-Path $env:TEMP 'rustup-init.exe'
  Invoke-WebRequest -Uri $base -OutFile $ri -UseBasicParsing
  # rustup-init is not Authenticode-signed; check the published sha256 (octet-stream -> bytes in PS 5.1)
  $r = Invoke-WebRequest -Uri "$base.sha256" -UseBasicParsing
  $txt = if ($r.Content -is [byte[]]) { [Text.Encoding]::ASCII.GetString($r.Content) } else { $r.Content }
  if ((($txt.Trim() -split '\s+')[0]) -ne (Get-FileHash $ri -Algorithm SHA256).Hash.ToLower()) { throw 'rustup-init sha256 mismatch' }
  & $ri -y --profile minimal --default-toolchain stable --default-host x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { $failed += "rustup-init ($LASTEXITCODE)" }
  Refresh-Path
}

# --- git (line endings BEFORE the first clone; identity is asked, never here)
git config --global core.autocrlf input
git config --global core.eol lf
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.syntax-theme 'Catppuccin Mocha'
git config --global merge.conflictstyle zdiff3
git config --global init.defaultBranch main
git config --global pull.rebase true

# --- npm postinstall policy (npm 11+, SETUP.md section 2 TRAP)
npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user

# --- shell: PS7 profile (+ PSFzf), starship, Windows Terminal
# -Force answers the untrusted-repository prompt for this one install; PSGallery
# itself stays Untrusted (no permanent trust change)
& pwsh -NoProfile -Command 'Install-Module PSFzf -Scope CurrentUser -Force'
if ($LASTEXITCODE -ne 0) { $failed += "Install-Module PSFzf ($LASTEXITCODE)" }
$prof = & pwsh -NoProfile -Command '$PROFILE'
New-Item -ItemType Directory -Force (Split-Path $prof), "$HOME\.config", "$env:APPDATA\mpv", "$HOME\.local\bin" | Out-Null
# backups: only the FIRST run's copy (a re-run must not overwrite the original)
if ((Test-Path $prof) -and -not (Test-Path "$prof.bak")) { Copy-Item $prof "$prof.bak" }
Copy-Item "$repo\dotfiles\windows\profile.ps1" $prof -Force
Copy-Item "$repo\dotfiles\starship.toml" "$HOME\.config\starship.toml" -Force
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if ((Test-Path $wt) -and -not (Test-Path "$wt.bak-machine-setup")) { Copy-Item $wt "$wt.bak-machine-setup" }
New-Item -ItemType Directory -Force (Split-Path $wt) | Out-Null
Copy-Item "$repo\dotfiles\windows\windows-terminal.json" $wt -Force

# --- mpv config + offer it for .m3u8 (its installer doesn't register that extension)
Copy-Item "$repo\dotfiles\windows\mpv.conf" "$env:APPDATA\mpv\mpv.conf" -Force
New-Item -Path 'HKCU:\Software\Classes\.m3u8\OpenWithProgids' -Force | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Classes\.m3u8\OpenWithProgids' -Name 'mpv.file' -Value ([byte[]]@()) -PropertyType None -Force | Out-Null

# --- PowerToys: Awake only (Caffeine), updates via winget/upall only
$pt = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
if (Test-Path $pt) {
  if (-not (Test-Path "$pt.bak-machine-setup")) { Copy-Item $pt "$pt.bak-machine-setup" }
  Get-Process PowerToys* -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $j = Get-Content $pt -Raw | ConvertFrom-Json
  foreach ($k in $j.enabled.PSObject.Properties.Name) { $j.enabled.$k = ($k -eq 'Awake') }
  $j.download_updates_automatically = $false; $j.show_new_updates_toast_notification = $false
  # no BOM: PowerToys silently resets a settings.json it can't parse (PS 5.1 utf8 = BOM)
  [IO.File]::WriteAllText($pt, ($j | ConvertTo-Json -Depth 10 -Compress), (New-Object Text.UTF8Encoding $false))
  # per-user install (winget default) or machine-wide
  $ptexe = "$env:LOCALAPPDATA\PowerToys\PowerToys.exe", "$env:ProgramFiles\PowerToys\PowerToys.exe" |
    Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($ptexe) { Start-Process $ptexe } else { Write-Warning 'PowerToys.exe not found in either install path - start PowerToys by hand' }
} else { 'PowerToys has no settings yet: start it once, then re-run bootstrap' }

if ($Debloat) {
  $apps = 'Microsoft.GamingApp','Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider',
          'Microsoft.XboxSpeechToTextOverlay','Microsoft.Xbox.TCUI','Clipchamp.Clipchamp','Microsoft.MicrosoftSolitaireCollection',
          'Microsoft.BingNews','Microsoft.BingWeather','MicrosoftWindows.Client.WebExperience','MSTeams',
          'Microsoft.OutlookForWindows','microsoft.windowscommunicationsapps','Microsoft.PowerAutomateDesktop',
          'Microsoft.Windows.DevHome','Microsoft.WindowsMaps','Microsoft.People','Microsoft.WindowsFeedbackHub',
          'Microsoft.GetHelp','Microsoft.MicrosoftOfficeHub','Microsoft.Todos','Microsoft.StartExperiencesApp',
          'Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.Copilot'
  foreach ($a in $apps) { Get-AppxPackage -Name $a | Remove-AppxPackage -ErrorAction SilentlyContinue }
}

# --- verify + stamp (no last-applied stamp when something failed)
Copy-Item "$repo\os\windows\verify.ps1" "$HOME\.local\bin\machine-verify.ps1" -Force
if ($failed.Count) {
  ''; 'FAILED (last-applied not stamped):'; $failed | ForEach-Object { "  $_" }
  exit 1
}
$rec = "$repo\machines\thinkpad-p14s-windows.md"
if (Test-Path $rec) {
  $lines = (Get-Content $rec -Encoding utf8) -replace '^last-applied: .*', "last-applied: $(Get-Date -Format yyyy-MM-dd)"
  # UTF-8 without BOM, LF (PS 5.1's Set-Content -Encoding utf8 writes a BOM)
  [IO.File]::WriteAllText($rec, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
}
'bootstrap done - GUI steps left: see SETUP.md section 2b. Run: machine-verify'
