# bootstrap (Windows) - the judgment-free part of SETUP.md section 2b, written from
# the first Windows session (2026-10-24, thinkpad-p14s dual-boot slice).
# Run from the repo root in Windows PowerShell 5.1 or pwsh, NOT elevated:
#   powershell -ExecutionPolicy Bypass -File os\windows\bootstrap.ps1 [-System] [-Debloat]
# -System  : also the admin items (one UAC prompt): hibernation off, System
#            Protection on C: (5 GB cap) + a restore point.
# -Debloat : remove the Store apps the owner removed on 2026-10-24 (current user).
# -Rust    : rustup (minimal, msvc, sha256-checked) + VS Build Tools C++ workload
#            (UAC, ~6.5 GB). Smart App Control must be turned OFF by hand to run
#            local builds - a one-way switch, so never scripted (section 2b).
# Overwrites its config files unconditionally (backs up WT/PowerToys/profile
# first). Not covered (GUI or identity - see section 2b): Chrome/mpv defaults, Vantage
# charge threshold, git user.name/email, gh auth login, Windows Hello, BIOS.
param([switch]$System, [switch]$Debloat, [switch]$Rust)
$ErrorActionPreference = 'Stop'
$repo = Resolve-Path "$PSScriptRoot\..\.."
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }

if ($System) {
  $s = @'
powercfg /h off
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
Enable-ComputerRestore -Drive 'C:\'
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5GB
Checkpoint-Computer -Description 'machine-setup: bootstrap' -RestorePointType MODIFY_SETTINGS
'@
  $f = Join-Path $env:TEMP 'machine-setup-system.ps1'; Set-Content $f $s -Encoding utf8
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""
}

# --- packages (winget; first-party package manager - section 2b)
$ids = 'Git.Git','Microsoft.PowerShell','GitHub.cli','dandavison.delta','JesseDuffield.lazygit',
       'Starship.Starship','ajeetdsouza.zoxide','junegunn.fzf','Atuinsh.Atuin','eza-community.eza',
       'sharkdp.bat','muesli.duf','aristocratos.btop4win','Neovim.Neovim','DEVCOM.JetBrainsMonoNerdFont',
       'OpenJS.NodeJS.LTS','pnpm.pnpm','Microsoft.VisualStudioCode','shinchiro.mpv',
       'Mozilla.Thunderbird','Bitwarden.Bitwarden','Spotify.Spotify','Microsoft.PowerToys'
foreach ($i in $ids) {
  winget install --id $i --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
  "$i exit=$LASTEXITCODE"
}
winget pin add --id OpenJS.NodeJS.LTS --version '24.*' --accept-source-agreements --disable-interactivity | Out-Null
Refresh-Path

if ($Rust) {
  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --accept-package-agreements --accept-source-agreements --disable-interactivity `
    --override '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
  $base = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'
  $ri = Join-Path $env:TEMP 'rustup-init.exe'
  Invoke-WebRequest -Uri $base -OutFile $ri -UseBasicParsing
  # rustup-init is not Authenticode-signed; check the published sha256 (octet-stream -> bytes in PS 5.1)
  $r = Invoke-WebRequest -Uri "$base.sha256" -UseBasicParsing
  $txt = if ($r.Content -is [byte[]]) { [Text.Encoding]::ASCII.GetString($r.Content) } else { $r.Content }
  if ((($txt.Trim() -split '\s+')[0]) -ne (Get-FileHash $ri -Algorithm SHA256).Hash.ToLower()) { throw 'rustup-init sha256 mismatch' }
  & $ri -y --profile minimal --default-toolchain stable --default-host x86_64-pc-windows-msvc
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
& pwsh -NoProfile -Command 'Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module PSFzf -Scope CurrentUser -Force'
$prof = & pwsh -NoProfile -Command '$PROFILE'
New-Item -ItemType Directory -Force (Split-Path $prof), "$HOME\.config", "$env:APPDATA\mpv", "$HOME\.local\bin" | Out-Null
if (Test-Path $prof) { Copy-Item $prof "$prof.bak" -Force }
Copy-Item "$repo\dotfiles\windows\profile.ps1" $prof -Force
Copy-Item "$repo\dotfiles\starship.toml" "$HOME\.config\starship.toml" -Force
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wt) { Copy-Item $wt "$wt.bak-machine-setup" -Force }
New-Item -ItemType Directory -Force (Split-Path $wt) | Out-Null
Copy-Item "$repo\dotfiles\windows\windows-terminal.json" $wt -Force

# --- mpv config + offer it for .m3u8 (its installer doesn't register that extension)
Copy-Item "$repo\dotfiles\windows\mpv.conf" "$env:APPDATA\mpv\mpv.conf" -Force
New-Item -Path 'HKCU:\Software\Classes\.m3u8\OpenWithProgids' -Force | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Classes\.m3u8\OpenWithProgids' -Name 'mpv.file' -Value ([byte[]]@()) -PropertyType None -Force | Out-Null

# --- PowerToys: Awake only (Caffeine), updates via winget/upall only
$pt = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
if (Test-Path $pt) {
  Copy-Item $pt "$pt.bak-machine-setup" -Force
  Get-Process PowerToys* -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $j = Get-Content $pt -Raw | ConvertFrom-Json
  foreach ($k in $j.enabled.PSObject.Properties.Name) { $j.enabled.$k = ($k -eq 'Awake') }
  $j.download_updates_automatically = $false; $j.show_new_updates_toast_notification = $false
  $j | ConvertTo-Json -Depth 10 -Compress | Set-Content $pt -Encoding utf8
  Start-Process "$env:LOCALAPPDATA\PowerToys\PowerToys.exe"
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

# --- verify + stamp
Copy-Item "$repo\os\windows\verify.ps1" "$HOME\.local\bin\machine-verify.ps1" -Force
$rec = "$repo\machines\thinkpad-p14s-windows.md"
if (Test-Path $rec) {
  $lines = (Get-Content $rec -Encoding utf8) -replace '^last-applied: .*', "last-applied: $(Get-Date -Format yyyy-MM-dd)"
  # UTF-8 without BOM, LF (PS 5.1's Set-Content -Encoding utf8 writes a BOM)
  [IO.File]::WriteAllText($rec, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
}
'bootstrap done - GUI steps left: see SETUP.md section 2b. Run: machine-verify'
