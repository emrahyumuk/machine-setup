# machine-verify (Windows) - every VERIFY line of SETUP.md section 2b (+ section 3a items
# translated for the dual-boot slice) as PASS/FAIL. Read-only; no admin needed.
# Installed by bootstrap.ps1 as ~/.local/bin/machine-verify.ps1.
$ErrorActionPreference = 'Continue'
$script:pass = 0; $script:fail = 0; $script:skip = 0
# A probe that throws is a FAIL, never a PASS: tests compare against the wanted
# value (-eq), and probes whose silence would read as "fine" use -ErrorAction Stop.
function Check([string]$name, [scriptblock]$test) {
  $ok = $false
  try { $ok = [bool](& $test) } catch { $ok = $false }
  if ($ok) { $script:pass++; "PASS  $name" } else { $script:fail++; "FAIL  $name" }
}
function Skip([string]$name) { $script:skip++; "SKIP  $name" }
# Default-app ProgId: Windows 11 24H2+ writes UserChoiceLatest (ProgId in a
# subkey of the same name), older builds UserChoice - read the new one first.
function Get-ProgId([string]$base) {
  foreach ($p in "$base\UserChoiceLatest\ProgId", "$base\UserChoiceLatest", "$base\UserChoice") {
    $v = (Get-ItemProperty $p -Name ProgId -ErrorAction SilentlyContinue).ProgId
    if ($v) { return $v }
  }
}
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# --- section 3a translated: dual-boot hygiene + battery
Check 'hibernation off (no Fast Startup, no hiberfil.sys)' {
  (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power').HibernateEnabled -eq 0 -and
  (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled -eq 0
}
Check 'charge threshold set in Vantage (start 75 / stop 80)' {
  $hit = Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Lenovo\PWRMGRV\ConfKeys\Data','HKLM:\SOFTWARE\Lenovo\PWRMGRV\ConfKeys\Data' -Recurse -ErrorAction SilentlyContinue |
    Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.ChargeStopPercentage -eq 80 -and $_.ChargeStartPercentage -eq 75 }
  [bool]$hit
}

# --- section 2b safety layer
# (restore-point listing needs admin; RPSessionInterval flips 0 -> 1 when protection is on)
Check 'System Protection on' { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore').RPSessionInterval -eq 1 }

# --- section 2b Git
Check 'git core.autocrlf = input' { (git config --global core.autocrlf) -eq 'input' }
Check 'git core.eol = lf'         { (git config --global core.eol) -eq 'lf' }
Check 'git user.email set'        { [bool](git config --global --get user.email) }
Check 'git core.pager = delta'    { (git config --global core.pager) -eq 'delta' }
Check 'gh authenticated'          { gh auth status *> $null; $LASTEXITCODE -eq 0 }

# --- CLI stack
foreach ($t in 'pwsh','git','gh','delta','lazygit','starship','zoxide','fzf','atuin','eza','bat','duf','btop4win','nvim','node','pnpm','code') {
  Check "command: $t" { [bool](Get-Command $t -ErrorAction SilentlyContinue) }
}
# [role] Rust/MSVC builds (section 2b "Rust + MSVC"): checked only where rustup is installed
if (Test-Path "$HOME\.cargo\bin\rustup.exe") {
  Check 'rustc (msvc host)' { (& "$HOME\.cargo\bin\rustc.exe" -vV | Select-String '^host:') -match 'pc-windows-msvc' }
  Check 'MSVC build tools present' {
    [bool](& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
  }
  Check 'VS installer keeps no payload cache (KeepDownloadedPayloads=0)' {
    (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\VisualStudio\Setup' -ErrorAction Stop).KeepDownloadedPayloads -eq 0
  }
  Check 'Smart App Control off (local builds can run)' {
    (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction Stop).VerifiedAndReputablePolicyState -eq 0
  }
} else { Skip 'Rust/MSVC/Smart App Control (role item; rustup not installed)' }
Check 'node is 24.x (one LTS line, APPS.md)' { (node --version) -like 'v24.*' }
Check 'winget pin keeps Node on 24.*' {
  $l = winget pin list --disable-interactivity | Select-String 'OpenJS\.NodeJS\.LTS' | Select-Object -First 1
  [bool]$l -and ($l.Line -match '\s24\.\*(\s|$)')
}
Check 'npm allow-scripts lists opencode-ai'  { (npm config get allow-scripts) -match 'opencode-ai' }

# --- shell + terminal wiring
$prof = & pwsh -NoProfile -Command '$PROFILE'
Check 'PS7 profile installed' { (Test-Path $prof) -and (Select-String -Path $prof -Pattern 'starship init powershell' -Quiet) }
Check 'Shift+Enter = AddLine in profile' { Select-String -Path $prof -Pattern "Shift\+Enter' -Function AddLine" -Quiet }
Check 'profile defines upcheck/upall (update cadence)' {
  (Select-String -Path $prof -Pattern '^function upcheck' -Quiet) -and (Select-String -Path $prof -Pattern '^function upall' -Quiet)
}
# OneDrive Known Folder Move: the profile folder must stay local (FILE_ATTRIBUTE_PINNED)
$pdir = Split-Path $prof
if ($pdir -match '\\OneDrive') {
  Check 'PS profile folder pinned always-local' { ([int64](Get-Item $pdir -Force -ErrorAction Stop).Attributes -band 0x80000) -ne 0 }
} else { Skip 'PS profile folder pin (profile not under OneDrive)' }
Check 'starship.toml present' { Test-Path "$HOME\.config\starship.toml" }
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Check 'Windows Terminal: Catppuccin Mocha + Nerd Font + Shift+Enter sendInput' {
  $j = Get-Content $wt -Raw -ErrorAction Stop | ConvertFrom-Json
  # the keybinding only names an action id; the action must be sendInput ESC CR
  $ids = @($j.keybindings | Where-Object { $_.keys -eq 'shift+enter' } | ForEach-Object id)
  $act = @($j.actions | Where-Object { $ids -contains $_.id -and $_.command.action -eq 'sendInput' -and $_.command.input -eq "$([char]27)`r" })
  $j.profiles.defaults.colorScheme -eq 'Catppuccin Mocha' -and
  $j.profiles.defaults.font.face -eq 'JetBrainsMono Nerd Font' -and
  $act.Count -gt 0
}
Check 'JetBrainsMono Nerd Font installed' {
  [bool](Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts","$env:WINDIR\Fonts" -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue)
}

# --- mpv
Check 'mpv.conf with d3d11va-copy + deinterlace' {
  $c = Get-Content "$env:APPDATA\mpv\mpv.conf" -Raw
  $c -match 'hwdec=d3d11va-copy' -and $c -match 'deinterlace=yes'
}
Check 'mpv is the .mp4 default' {
  (Get-ProgId 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.mp4') -match 'mpv'
}

# --- defaults / PowerToys
Check 'Chrome is the default browser' {
  (Get-ProgId 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https') -eq 'ChromeHTML'
}
$ptj = Get-Content "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
Check 'PowerToys: only Awake enabled' {
  (($ptj.enabled.PSObject.Properties | Where-Object Value | ForEach-Object Name) -join ',') -eq 'Awake'
}
Check 'PowerToys: no auto-download (updates via upall)' { $ptj.download_updates_automatically -eq $false }

# --- debloat (same list as bootstrap.ps1 -Debloat - keep the two in sync; a
# feature update may bring some back)
Check 'debloat list absent (current user)' {
  $apps = 'Microsoft.GamingApp','Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider',
          'Microsoft.XboxSpeechToTextOverlay','Microsoft.Xbox.TCUI','Clipchamp.Clipchamp','Microsoft.MicrosoftSolitaireCollection',
          'Microsoft.BingNews','Microsoft.BingWeather','MicrosoftWindows.Client.WebExperience','MSTeams',
          'Microsoft.OutlookForWindows','microsoft.windowscommunicationsapps','Microsoft.PowerAutomateDesktop',
          'Microsoft.Windows.DevHome','Microsoft.WindowsMaps','Microsoft.People','Microsoft.WindowsFeedbackHub',
          'Microsoft.GetHelp','Microsoft.MicrosoftOfficeHub','Microsoft.Todos','Microsoft.StartExperiencesApp',
          'Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.Copilot'
  # Appx cmdlets are not native in pwsh 7: ask Windows PowerShell 5.1
  $global:LASTEXITCODE = 1
  $names = @(powershell.exe -NoProfile -Command "`$ErrorActionPreference='Stop'; Get-AppxPackage | ForEach-Object Name")
  if ($global:LASTEXITCODE -ne 0 -or -not $names) { throw 'Get-AppxPackage failed' }
  $left = @($names | Where-Object { $apps -contains $_ } | Sort-Object -Unique)
  if ($left) { Write-Host "  still installed: $($left -join ', ')" }
  $left.Count -eq 0
}

# --- sign-in (Windows Hello)
Check 'Microsoft account sign-in, no auto-login' {
  $u = Get-LocalUser -Name $env:USERNAME -ErrorAction Stop
  $wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
  # string compare: PS 7 may hand back a deserialized LocalUser (WinCompat), where
  # PrincipalSource is a string; an absent AutoAdminLogon counts as off
  "$($u.PrincipalSource)" -eq 'MicrosoftAccount' -and "$($wl.AutoAdminLogon)" -ne '1'
}

''
"$script:pass PASS / $script:fail FAIL / $script:skip SKIP"
if ($script:fail) { exit 1 }
