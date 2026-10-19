#!/bin/bash
# os/macos/github-runner-job-completed.sh — [role] SETUP.md §3b "GitHub Actions
# runner". The runner's job-completed hook (ACTIONS_RUNNER_HOOK_JOB_COMPLETED in
# assets/com.machine-setup.github-runner.plist). Runs as the runner user after
# every job, so nothing a job leaves behind — its checkout, a signing keychain,
# a certificate file — is there for the next one. The tool cache (_work/_tool)
# stays: it is what makes the next job fast.
#
# Installed as a root-owned copy (/usr/local/libexec/machine-setup/), not a
# symlink: the runner user cannot read the owner's home. Its output lands in
# the job log under "Complete runner". A non-zero exit fails the job: only a
# leftover that could not be removed, or a signing identity still there, does.
set -u

# The job's repo directory, _work/<repo> (GITHUB_WORKSPACE is
# _work/<repo>/<repo>). Never _work itself or the runner's own _tool, _temp,
# _actions.
work="$HOME/actions-runner/_work"
repo_dir=$(dirname "${GITHUB_WORKSPACE:-/}")
case "$repo_dir" in
  "$work"/_*) echo "workspace: left $repo_dir (runner-owned)" ;;
  "$work"/*) rm -rf "$repo_dir" || { echo "workspace: FAILED to remove $repo_dir"; exit 1; }
             echo "workspace: removed $repo_dir" ;;
  *) echo "workspace: nothing under $work (GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-unset})" ;;
esac

# Every keychain a job created (build.keychain, or the temporary one a bundler
# makes and a crashed build leaves), not only the one the workflow names.
# Deleting one also drops it from the search list. The login keychain, if the
# user ever gets one, stays and becomes the default again; the runner user,
# never logged in, has none, and then no default is the clean state.
for k in "$HOME"/Library/Keychains/*.keychain-db; do
  [ -e "$k" ] || continue
  case "$k" in */login.keychain-db) continue ;; esac
  security delete-keychain "$k" && echo "keychain: removed ${k##*/}"
done
if [ -f "$HOME/Library/Keychains/login.keychain-db" ]; then
  security default-keychain -s login.keychain
fi
echo "keychain: default now $(security default-keychain 2>&1 | tr -d ' "')"

# Certificate files: the runner's home outside Library (privacy-protected
# folders a daemon may not list), the cargo registry and the tool cache
# (crates and tools ship .p12 test fixtures), plus the user's files in /tmp —
# launchd gives the daemon no TMPDIR, so mktemp writes there.
# Traversal errors are not failures; a .p12 still there afterwards is.
# No find -delete: on macOS it implies -depth, which makes -prune a no-op.
p12s() {
  find "$HOME" \( -path "$HOME/Library" -o -path "$HOME/.cargo" -o -path "$work/_tool" \) -prune \
    -o -name '*.p12' -type f -print 2>/dev/null
  find /private/tmp -user "$(id -u)" -name '*.p12' -type f -print 2>/dev/null
}
p12s | while IFS= read -r f; do rm -f "$f" && echo "p12: removed $f"; done
left=$(p12s)
[ -z "$left" ] || { echo "p12: FAILED to remove: $left"; fail=1; }

# The point of it all: no code-signing identity outlives the job.
ids=$(security find-identity -v -p codesigning | awk '/valid identities found/{print $1}')
echo "keychain: $ids code-signing identities left"
[ "$ids" = 0 ] || { echo "keychain: FAILED, a signing identity outlived the job"; fail=1; }
exit "${fail:-0}"
