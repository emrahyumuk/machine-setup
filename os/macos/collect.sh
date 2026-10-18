#!/bin/bash
# Regenerates inventory/<machine-os>/ + dotfiles/macos/ from the current
# machine state, and stamps the machine record (machines/<machine-os>.md).
# Run after installing/removing things; review the diff, then commit.
# macOS counterpart of os/fedora/collect.sh.
#
# PRIVACY RULE: inventory holds CONFIG (deliberate choices), never STATE.
# No serials, hardware UUIDs, MACs, tailnet IPs, pairing data or account ids.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root
MID=mbp14-macos
INV=inventory/$MID
mkdir -p "$INV"
export HOMEBREW_NO_AUTO_UPDATE=1

echo "== system =="
{
  echo "collected: $(date +%F)"
  echo "os: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))   # informational only"
  # Model + chip + RAM only — system_profiler also prints serial/UUID, never copy those
  system_profiler SPHardwareDataType 2>/dev/null \
    | sed -nE 's/^ +Model Name: (.*)$/model: \1/p; s/^ +Model Identifier: (.*)$/model-id: \1/p; s/^ +Chip: (.*)$/chip: \1/p; s/^ +Memory: (.*)$/memory: \1/p'
} > $INV/system.txt

echo "== brew (RAW appendix — curated view lives in APPS.md) =="
brew leaves --installed-on-request 2>/dev/null | sort > $INV/brew-formulae.txt
brew list --cask 2>/dev/null | sort > $INV/brew-casks.txt
{ mas list 2>/dev/null | sed -E 's/ +\(.*\)$//' | sort; } > $INV/mas.txt || true

echo "== browser extensions (annotations live in APPS.md 'Browsers') =="
# Names + ids only — never extension storage (vault data, API keys).
python3 -I - > $INV/browser-extensions.txt <<'PY'
import json, glob, os
H = os.path.expanduser("~")
print("# firefox (name | id)")
for prof in sorted(glob.glob(H+"/Library/Application Support/Firefox/Profiles/*/")):
    f = prof + "extensions.json"
    if not os.path.exists(f):
        continue
    addons = [a for a in json.load(open(f))["addons"]
              if a.get("type") == "extension" and a.get("location") == "app-profile"]
    if not addons:
        continue
    print(f"## profile {os.path.basename(prof.rstrip('/'))}")
    for a in sorted(addons, key=lambda a: (not a.get("active"), (a.get("defaultLocale") or {}).get("name",""))):
        print(f"{'on ' if a.get('active') else 'off'} {(a.get('defaultLocale') or {}).get('name','?')} | {a['id']}")
print("# google-chrome (name | id)")
for prof in sorted(glob.glob(H+"/Library/Application Support/Google/Chrome/*/Preferences")):
    try:
        d = json.load(open(prof)).get("extensions", {}).get("settings", {})
    except Exception:
        continue
    base = os.path.dirname(prof)
    rows = []
    for eid, v in d.items():
        if v.get("location") not in (1, 0):          # skip component/default-installed
            continue
        vers = sorted(glob.glob(f"{base}/Extensions/{eid}/*/manifest.json"))
        if not vers:
            continue
        m = json.load(open(vers[-1]))
        name = m.get("name", "?")
        if name.startswith("__MSG_"):
            key = name[6:-2]
            for loc in glob.glob(os.path.dirname(vers[-1]) + "/_locales/en*/messages.json"):
                try:
                    name = json.load(open(loc))[key]["message"]; break
                except Exception:
                    pass
        rows.append((bool(v.get("disable_reasons")), name, eid))
    if rows:
        print(f"## profile {os.path.basename(base)}")
        for dis, name, eid in sorted(rows):
            print(f"{'off' if dis else 'on '} {name} | {eid}")
PY

echo "== macOS settings (whitelisted keys — choices, not state) =="
{
  echo "# defaults read <domain> <key> → value. Whitelist only (privacy rule)."
  rd() { printf '%s %s = %s\n' "$1" "$2" "$(defaults read "$1" "$2" 2>/dev/null || echo '(unset)')"; }
  rd -g AppleInterfaceStyle
  rd -g AppleAccentColor
  rd -g com.apple.swipescrolldirection
  rd com.apple.dock orientation
  rd com.apple.dock autohide
  rd com.apple.AppleMultitouchMouse MouseButtonMode
  rd com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode
  rd com.colliderli.iina useUserDefinedConfDir
  rd /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates
  rd /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall
  echo "# pmset (AC)"
  pmset -g custom 2>/dev/null | sed -n '/^AC Power:/,$p' | grep -E '^ +(sleep|displaysleep|disksleep|womp|powernap|standby) '
} > $INV/macos-settings.txt

echo "== dev tool globals =="
{
  echo "# npm -g (brew node@24)"
  npm ls -g --depth=0 --parseable 2>/dev/null | tail -n+2 | xargs -n1 basename || true
  echo "# rustup targets"
  rustup target list --installed 2>/dev/null || true
} > $INV/dev-globals.txt

echo "== dotfiles (macOS-specific copies; shared ones only compared) =="
mkdir -p dotfiles/macos
cp ~/.zshrc    dotfiles/macos/zshrc
cp ~/.zprofile dotfiles/macos/zprofile
cp ~/.zshenv   dotfiles/macos/zshenv
cp ~/.config/mpv/mpv.conf dotfiles/macos/mpv.conf 2>/dev/null || true
# ghostty + starship are SHARED with Fedora: never overwrite from here, just flag drift
cmp -s ~/.config/ghostty/config dotfiles/ghostty.config || echo "!! ghostty config differs from dotfiles/ghostty.config — decide which side wins" >&2
cmp -s ~/.config/starship.toml  dotfiles/starship.toml  || echo "!! starship.toml differs from dotfiles/starship.toml — decide which side wins" >&2
if grep -rqiE "token|secret|password|api[_-]?key|BEGIN (RSA|EC|OPENSSH)" dotfiles/macos/; then
  echo "!! possible secret in dotfiles/macos/ — review before committing" >&2
fi

echo "== machine record: stamp last-collected / last-verified =="
M=machines/$MID.md
if [ -f "$M" ]; then
  sed -i '' "s/^last-collected: .*/last-collected: $(date +%F)/" "$M"
  if os/macos/verify.sh >/dev/null 2>&1; then
    sed -i '' "s/^last-verified: .*/last-verified: $(date +%F)/" "$M"; echo "  verify: all PASS → last-verified stamped"
  else
    echo "  verify: FAILs present → last-verified NOT stamped (run os/macos/verify.sh to see)"
  fi
fi

echo
echo "Done → $INV/ + dotfiles/macos/ + $M. Review the diff before committing."
