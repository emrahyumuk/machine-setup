# collect (Windows) - inventory + dotfiles back into the repo + machine-record
# stamps. Run from the repo root (not elevated):
#   powershell -ExecutionPolicy Bypass -File os\windows\collect.ps1
# Writes inventory/thinkpad-p14s-windows/. Config only - no identities: the git
# [user] block and anything under ~/.claude stay out (README privacy rule).
$repo = Resolve-Path "$PSScriptRoot\..\.."
$inv = "$repo\inventory\thinkpad-p14s-windows"

# Names that must not reach the PUBLIC repo (unreleased/private software): the
# repo-root .collect-exclude, gitignored, shared with os/fedora/collect.sh and
# with its semantics - one regex per line, matched against the WHOLE name
# (grep -x). Here case-insensitive and tested against every inventory field:
# program display name, winget id, Store app name, extension id and name.
# No file = no filter, so stop before writing anything (an empty file is fine).
$exf = "$repo\.collect-exclude"
if (-not (Test-Path $exf)) {
  Write-Host "STOP: $exf is missing - nothing was written." -ForegroundColor Red
  Write-Host 'Without it private names would land in the public inventory. Create it (empty is' -ForegroundColor Red
  Write-Host 'fine; copy it from the Fedora clone), one regex per line, then re-run.' -ForegroundColor Red
  if (Test-Path "$HOME\.config\machine-setup\collect-exclude.txt") {
    Write-Host "(an older list exists at ~\.config\machine-setup\collect-exclude.txt - move it there)" -ForegroundColor Red
  }
  exit 1
}
$ex = @(Get-Content $exf -Encoding utf8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' })
function Test-Excluded([string[]]$names) {
  foreach ($n in $names) { foreach ($p in $ex) { if ($n -match "^(?:$p)$") { return $true } } }
  $false
}

New-Item -ItemType Directory -Force $inv | Out-Null
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
# UTF-8 without BOM, LF - PS 5.1's Set-Content -Encoding utf8 writes a BOM
$utf8 = New-Object Text.UTF8Encoding $false
function Write-Utf8([string]$path) { [IO.File]::WriteAllText($path, (($input | Out-String -Stream) -join "`n") + "`n", $utf8) }

# system summary (no serials, no MACs, no hostname-independent ids)
$cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem
@(
  "model: $($cs.SystemFamily) ($($cs.Model))"
  "os: $($os.Caption) $($os.Version) $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion)"
  "bios: $((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion)"
  "cpu: $((Get-CimInstance Win32_Processor).Name.Trim())"
  "gpu: $((Get-CimInstance Win32_VideoController).Name) driver $((Get-CimInstance Win32_VideoController).DriverVersion)"
  "ram-visible-gb: $([math]::Round($cs.TotalPhysicalMemory/1GB,1))"
) | Write-Utf8 "$inv\system.txt"

# winget-managed packages (ids only), Store apps, desktop programs
# (winget export goes to a temp file first: the exclude filter runs before the repo copy)
$wtmp = Join-Path $env:TEMP 'machine-setup-winget.json'
Remove-Item $wtmp -ErrorAction SilentlyContinue
winget export -o $wtmp --accept-source-agreements --disable-interactivity | Out-Null
if (Test-Path $wtmp) {
  $wj = Get-Content $wtmp -Raw -Encoding utf8 | ConvertFrom-Json
  foreach ($src in $wj.Sources) { $src.Packages = @($src.Packages | Where-Object { -not (Test-Excluded $_.PackageIdentifier) }) }
  $wj | ConvertTo-Json -Depth 10 | Write-Utf8 "$inv\winget.json"
  Remove-Item $wtmp
} else { Write-Host 'winget export FAILED - winget.json left as it was' -ForegroundColor Yellow }
Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
  Select-Object -ExpandProperty Name | Sort-Object | Where-Object { -not (Test-Excluded $_) } | Write-Utf8 "$inv\appx.txt"
$keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object DisplayName |
  Select-Object -ExpandProperty DisplayName | Sort-Object -Unique |
  Where-Object { -not (Test-Excluded $_) } | Write-Utf8 "$inv\programs.txt"

# browser extensions (Chrome Default profile: id + name). A __MSG_key__ name is
# resolved from _locales/<default_locale>/messages.json; else the placeholder stays.
$ext = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
if (Test-Path $ext) {
  Get-ChildItem $ext -Directory | ForEach-Object {
    $m = Get-ChildItem $_.FullName -Recurse -Filter manifest.json -Depth 1 | Select-Object -First 1
    if ($m) {
      $mj = Get-Content $m.FullName -Raw -Encoding utf8 | ConvertFrom-Json
      $name = $mj.name
      if ($name -match '^__MSG_(.+)__$' -and $mj.default_locale) {
        $key = $Matches[1]
        $msgf = Join-Path $m.DirectoryName "_locales\$($mj.default_locale)\messages.json"
        if (Test-Path $msgf) {
          try { $t = (Get-Content $msgf -Raw -Encoding utf8 | ConvertFrom-Json).$key.message; if ($t) { $name = $t } } catch { }
        }
      }
      if (-not (Test-Excluded @($_.Name, $name))) { "$($_.Name)  $name" }
    }
  } | Write-Utf8 "$inv\browser-extensions.txt"
}

# dotfiles back into the repo (the machine is the source after hand edits)
$prof = & pwsh -NoProfile -Command '$PROFILE'
if (Test-Path $prof) { Copy-Item $prof "$repo\dotfiles\windows\profile.ps1" -Force }
Copy-Item "$env:APPDATA\mpv\mpv.conf" "$repo\dotfiles\windows\mpv.conf" -Force -ErrorAction SilentlyContinue
# Windows Terminal is NOT copied back: it rewrites settings.json with generated
# profiles (VS Developer prompts, Azure) - machine state. Edit the repo copy.

# stamps
$today = Get-Date -Format yyyy-MM-dd
$rec = "$repo\machines\thinkpad-p14s-windows.md"
$lines = (Get-Content $rec -Encoding utf8) -replace '^last-collected: .*', "last-collected: $today"
# the REPO's verify (the installed copy may be stale). LASTEXITCODE is preset in
# the GLOBAL scope (a script-scope copy would shadow what pwsh sets), so a pwsh
# that never ran reads as a failure, and the summary line must be there too.
$global:LASTEXITCODE = 1
$vout = & pwsh -NoProfile -File "$repo\os\windows\verify.ps1"
$vrc = $global:LASTEXITCODE
if ($vrc -eq 0 -and ($vout -match ' PASS / ')) {
  $lines = $lines -replace '^last-verified: .*', "last-verified: $today"
} else {
  $vout | Where-Object { $_ -match '^FAIL' }
  "verify exit=$vrc - last-verified not stamped"
}
$lines | Write-Utf8 $rec
"collected into $inv"
