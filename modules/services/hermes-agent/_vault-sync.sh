#!/usr/bin/env bash
# Commit, rebase and push agent writes to a wiki vault, after the wiki gate audit passes.
# Usage: vault-sync <vault> <tree> [<dir>]   (dir: the tree's folder in the vault; omitted for the vault root)
# Environment:
#   WIKI_GATE         gate.py of the wiki-gate plugin
#   WIKI_PYTHON       Python that runs it
#   WIKI_INBOX_BASE   template for <dir>/review/inbox.base
#   WIKI_TOKEN_FILE   optional GitHub token; fetch and push then use HTTPS even for an SSH remote
set -euo pipefail

vault=$1
tree=$2
wiki=$vault${3:+/$3}

report() {
  printf '%s\n' "$1" >&2
  # The librarian's wiki-sync-report cron job shows this file in Hermes Desktop until a run succeeds.
  printf '%s\n' "$1" >"$last"
  exit 1
}

if [ ! -d "$vault/.git" ]; then
  echo "vault-sync: $vault is not a Git checkout yet; nothing to do" >&2
  exit 0
fi

# Hooks planted in the vault must never run, least of all with WIKI_TOKEN exported.
git() { command git -C "$vault" -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
gitdir=$(git rev-parse --absolute-git-dir)
last=$gitdir/vault-sync-report
held=$gitdir/vault-sync-held
rebasing() { [ -e "$gitdir/rebase-merge" ] || [ -e "$gitdir/rebase-apply" ]; }

if rebasing; then
  report "Wiki sync for $vault is paused: a rebase is in progress. Finish or abort it by hand."
fi

# Baseline that Obsidian and the librarian rely on. Existing files are left alone.
if [ -s "$vault/.gitignore" ] && [ -n "$(tail -c 1 "$vault/.gitignore")" ]; then
  echo >>"$vault/.gitignore"
fi
for line in .obsidian/ .trash/; do
  grep -qxF "$line" "$vault/.gitignore" 2>/dev/null || printf '%s\n' "$line" >>"$vault/.gitignore"
done
mkdir -p "$wiki/raw" "$wiki/review/applied" "$wiki/memory"
if [ ! -e "$wiki/review/inbox.base" ]; then
  # The template comes from the read-only Nix store; Obsidian saves view changes into the copy.
  install -m 0644 "$WIKI_INBOX_BASE" "$wiki/review/inbox.base"
fi

# Audit exactly what gets committed: a write landing after this add waits for the next run.
git add -A
status=0
audit=$("$WIKI_PYTHON" "$WIKI_GATE" audit "$vault" --held "$held" 2>&1) || status=$?
case $status in
  0) ;;
  1) report "Wiki sync committed nothing: a gold change has no applied proposal. Revert it or record its proposal.
$audit" ;;
  *) report "Wiki sync failed: the audit exited with $status.
$audit" ;;
esac
# A gold page whose proposal is still approved is mid-apply: commit it next run, with the moved proposal.
if [ -s "$held" ]; then
  git reset -q --pathspec-from-file="$held" --pathspec-file-nul
fi

if ! git diff --cached --quiet; then
  git commit -q -m "librarian: sync $tree $(date -u +%Y-%m-%dT%H:%MZ)"
fi

# A vault without any remote (Livia's) keeps local history only. Decide from config, not from
# whether the upstream ref resolves: a fresh remote has no ref yet.
remotes=$(git remote)
if [ -z "$remotes" ]; then
  rm -f "$last"
  exit 0
fi
branch=$(git symbolic-ref -q --short HEAD) || report "Wiki sync for $vault is paused: HEAD is detached. Check out the branch by hand."
origin=$(git config "branch.$branch.remote") || origin=$remotes
case $origin in
  *$'\n'*) report "Wiki sync for $vault is paused: $branch tracks no remote and the vault has several. Set its upstream by hand." ;;
esac
merge=$(git config "branch.$branch.merge") || merge=refs/heads/$branch
tracking=refs/remotes/$origin/${merge#refs/heads/}

remote=()
if [ -n "${WIKI_TOKEN_FILE:-}" ]; then
  WIKI_TOKEN=$(<"$WIKI_TOKEN_FILE")
  export WIKI_TOKEN
  # The helper reads the token from the environment, so it never reaches argv or Git config files.
  # shellcheck disable=SC2016
  remote=(
    -c url.https://github.com/.insteadOf=git@github.com:
    -c url.https://github.com/.insteadOf=ssh://git@github.com/
    -c credential.helper=
    -c 'credential.helper=!f() { test "$1" = get && printf "username=x-access-token\npassword=%s\n" "$WIKI_TOKEN"; }; f'
  )
fi

git "${remote[@]}" fetch -q "$origin" || report "Wiki sync could not fetch $vault; the local commit is kept and was not pushed."
# An empty remote has no branch yet: the push below creates it.
if git rev-parse -q --verify "$tracking" >/dev/null && ! git rebase -q "$tracking"; then
  if rebasing; then
    git rebase --abort
    report "Wiki sync hit a rebase conflict in $vault. The rebase was aborted; the local commit is kept and was not pushed. Resolve it by hand, then the next run pushes."
  fi
  report "Wiki sync could not rebase $vault; the local commit is kept and was not pushed."
fi
git "${remote[@]}" push -q -u "$origin" "HEAD:$merge" || report "Wiki sync could not push $vault; the local commit is kept."
rm -f "$last"
