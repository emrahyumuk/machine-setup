# machine-verify (Windows) — every VERIFY line of SETUP.md §2b (+ §3a items
# translated for the dual-boot slice) as PASS/FAIL. Read-only; no admin needed.
# Installed by bootstrap.ps1 as ~/.local/bin/machine-verify.ps1.
$ErrorActionPreference = 'Continue'
$script:pass = 0; $script:fail = 0
function Check([string]$name, [scriptblock]$test) {
  $ok = $false
  try { $ok = [bool](& $test) } catch { $ok = $false }
  if ($ok) { $script:pass++; "PASS  $name" } else { $script:fail++; "FAIL  $name" }
}
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# --- §3a translated: dual-boot hygiene + battery
Check 'hibernation off (no Fast Startup, no hiberfil.sys)' {
  (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power').HibernateEnabled -eq 0 -and
  (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled -eq 0
}
Check 'charge threshold set in Vantage (stop 80)' {
  $hit = Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Lenovo\PWRMGRV\ConfKeys\Data','HKLM:\SOFTWARE\Lenovo\PWRMGRV\ConfKeys\Data' -Recurse -ErrorAction SilentlyContinue |
    Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.ChargeStopPercentage -eq 80 }
  [bool]$hit
}

# --- §2b safety layer
# (restore-point listing needs admin; RPSessionInterval flips 0 -> 1 when protection is on)
Check 'System Protection on' { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore').RPSessionInterval -eq 1 }

# --- §2b Git
Check 'git core.autocrlf = input' { (git config --global core.autocrlf) -eq 'input' }
Check 'git core.eol = lf'         { (git config --global core.eol) -eq 'lf' }
Check 'git user.email set'        { [bool](git config --global --get user.email) }
Check 'git core.pager = delta'    { (git config --global core.pager) -eq 'delta' }
Check 'gh authenticated'          { gh auth status *> $null; $LASTEXITCODE -eq 0 }

# --- CLI stack
foreach ($t in 'pwsh','git','gh','delta','lazygit','starship','zoxide','fzf','atuin','eza','bat','duf','btop4win','nvim','node','pnpm','code') {
  Check "command: $t" { [bool](Get-Command $t -ErrorAction SilentlyContinue) }
}
Check 'node is 24.x (one LTS line, APPS.md)' { (node --version) -like 'v24.*' }
Check 'winget pin keeps Node on 24.*'        { [bool](winget pin list --disable-interactivity | Select-String 'OpenJS.NodeJS.LTS') }
Check 'npm allow-scripts lists opencode-ai'  { (npm config get allow-scripts) -match 'opencode-ai' }

# --- shell + terminal wiring
$prof = & pwsh -NoProfile -Command '$PROFILE'
Check 'PS7 profile installed' { (Test-Path $prof) -and (Select-String -Path $prof -Pattern 'starship init powershell' -Quiet) }
Check 'Shift+Enter = AddLine in profile' { Select-String -Path $prof -Pattern "Shift\+Enter' -Function AddLine" -Quiet }
Check 'starship.toml present' { Test-Path "$HOME\.config\starship.toml" }
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Check 'Windows Terminal: Catppuccin Mocha + Nerd Font + Shift+Enter sendInput' {
  $j = Get-Content $wt -Raw | ConvertFrom-Json
  $j.profiles.defaults.colorScheme -eq 'Catppuccin Mocha' -and
  $j.profiles.defaults.font.face -eq 'JetBrainsMono Nerd Font' -and
  [bool]($j.keybindings | Where-Object { $_.keys -eq 'shift+enter' })
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
  (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.mp4\UserChoice').ProgId -match 'mpv'
}

# --- defaults / PowerToys
Check 'Chrome is the default browser' {
  (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice').ProgId -eq 'ChromeHTML'
}
Check 'PowerToys: only Awake enabled' {
  $e = (Get-Content "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json" -Raw | ConvertFrom-Json).enabled
  (($e.PSObject.Properties | Where-Object Value | ForEach-Object Name) -join ',') -eq 'Awake'
}

# --- sign-in (Windows Hello)
Check 'account has a sign-in secret (not passwordless auto-login)' {
  (Get-LocalUser -Name $env:USERNAME).PrincipalSource -ne 'Local' -or (Get-LocalUser -Name $env:USERNAME).PasswordRequired
}

''
"$script:pass PASS / $script:fail FAIL"
if ($script:fail) { exit 1 }
