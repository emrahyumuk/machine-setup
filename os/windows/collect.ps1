# collect (Windows) — inventory + dotfiles back into the repo + machine-record
# stamps. Run from the repo root (not elevated):
#   powershell -ExecutionPolicy Bypass -File os\windows\collect.ps1
# Writes inventory/thinkpad-p14s-windows/. Config only — no identities: the git
# [user] block and anything under ~/.claude stay out (README privacy rule).
$repo = Resolve-Path "$PSScriptRoot\..\.."
$inv = "$repo\inventory\thinkpad-p14s-windows"
New-Item -ItemType Directory -Force $inv | Out-Null
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
# UTF-8 without BOM, LF — PS 5.1's Set-Content -Encoding utf8 writes a BOM
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
  "c-free-gb: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
) | Write-Utf8 "$inv\system.txt"

# winget-managed packages (ids only), Store apps, desktop programs
winget export -o "$inv\winget.json" --accept-source-agreements --disable-interactivity | Out-Null
Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
  Select-Object -ExpandProperty Name | Sort-Object | Write-Utf8 "$inv\appx.txt"
$keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object DisplayName |
  Select-Object -ExpandProperty DisplayName | Sort-Object -Unique | Write-Utf8 "$inv\programs.txt"

# browser extensions (Chrome Default profile: id + name)
$ext = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
if (Test-Path $ext) {
  Get-ChildItem $ext -Directory | ForEach-Object {
    $m = Get-ChildItem $_.FullName -Recurse -Filter manifest.json -Depth 1 | Select-Object -First 1
    if ($m) { "$($_.Name)  $((Get-Content $m.FullName -Raw | ConvertFrom-Json).name)" }
  } | Write-Utf8 "$inv\browser-extensions.txt"
}

# dotfiles back into the repo (the machine is the source after hand edits)
$prof = & pwsh -NoProfile -Command '$PROFILE'
if (Test-Path $prof) { Copy-Item $prof "$repo\dotfiles\windows\profile.ps1" -Force }
Copy-Item "$env:APPDATA\mpv\mpv.conf" "$repo\dotfiles\windows\mpv.conf" -Force -ErrorAction SilentlyContinue
Copy-Item "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" "$repo\dotfiles\windows\windows-terminal.json" -Force -ErrorAction SilentlyContinue

# stamps
$today = Get-Date -Format yyyy-MM-dd
$rec = "$repo\machines\thinkpad-p14s-windows.md"
$lines = (Get-Content $rec -Encoding utf8) -replace '^last-collected: .*', "last-collected: $today"
& pwsh -NoProfile -File "$HOME\.local\bin\machine-verify.ps1" | Out-Null
if ($LASTEXITCODE -eq 0) { $lines = $lines -replace '^last-verified: .*', "last-verified: $today" } else { 'verify has FAILs — last-verified not stamped' }
$lines | Write-Utf8 $rec
"collected into $inv"
