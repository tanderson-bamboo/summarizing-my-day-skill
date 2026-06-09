#!/usr/bin/env bash
# gather.sh — collect a day's activity for the summarizing-my-day skill.
# Emits a markdown report to stdout. NEVER touches JIRA. NEVER writes notes.
set -euo pipefail

SINCE=""
REPOS_DIR="${SUMMARIZE_REPOS_DIR:-$HOME/repos}"
HISTFILE_PATH="${SUMMARIZE_HISTFILE:-$HOME/.zsh_history}"
CLAUDE_PROJECTS="${SUMMARIZE_CLAUDE_PROJECTS:-$HOME/.claude/projects}"
GIT_EMAIL="${SUMMARIZE_GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo '')}"

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2;;
    --repos-dir) REPOS_DIR="$2"; shift 2;;
    --histfile) HISTFILE_PATH="$2"; shift 2;;
    --claude-projects) CLAUDE_PROJECTS="$2"; shift 2;;
    --git-email) GIT_EMAIL="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [ -z "$SINCE" ]; then
  echo "Error: --since <epoch> is required" >&2
  exit 2
fi

# Portable epoch formatting (BSD/macOS `date -r` vs GNU `date -d @`).
epoch_iso() { date -r "$1" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$1" '+%Y-%m-%d %H:%M'; }
epoch_touch() { date -r "$1" '+%Y%m%d%H%M.%S' 2>/dev/null || date -d "@$1" '+%Y%m%d%H%M.%S'; }

echo "# Activity since $(epoch_iso "$SINCE") (epoch ${SINCE})"
echo

# ---- Git commits + uncommitted ----
ticket_tmp="$(mktemp)"
marker=""
trap 'rm -f "$ticket_tmp" ${marker:+"$marker"}' EXIT

echo "## Git commits"
echo
for repo in "$REPOS_DIR"/*/; do
  [ -d "${repo}.git" ] || continue
  name="$(basename "$repo")"
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  echo "$branch" >> "$ticket_tmp"
  commits="$(git -C "$repo" log --all --author="$GIT_EMAIL" --since="@$SINCE" --pretty='%h %s' 2>/dev/null || true)"
  if [ -n "$commits" ]; then
    echo "### ${name} (branch: ${branch})"
    printf '```\n%s\n```\n\n' "$commits"
    echo "$commits" >> "$ticket_tmp"
  fi
done

echo "## Uncommitted changes"
echo
for repo in "$REPOS_DIR"/*/; do
  [ -d "${repo}.git" ] || continue
  name="$(basename "$repo")"
  status="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
  if [ -n "$status" ]; then
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    echo "### ${name} (branch: ${branch})"
    printf '```\n%s\n```\n\n' "$status"
  fi
done

# ---- Shell history ----
echo "## Shell commands"
printf '```\n'
if [ -f "$HISTFILE_PATH" ]; then
  LC_ALL=C awk -v since="$SINCE" '
    /^: [0-9]+:[0-9]+;/ {
      line=$0; sub(/^: /,"",line); split(line,a,":"); ts=a[1]+0;
      cmd=$0; sub(/^: [0-9]+:[0-9]+;/,"",cmd);
      inwin = (ts >= since);
      if (inwin) print cmd;
      next;
    }
    { if (inwin) print }
  ' "$HISTFILE_PATH" 2>/dev/null || true
fi
printf '```\n\n'

# ---- Claude transcripts (modified in window) ----
echo "## Claude sessions (transcripts modified in window)"
echo
if [ -d "$CLAUDE_PROJECTS" ]; then
  marker="$(mktemp)"
  touch -t "$(epoch_touch "$SINCE")" "$marker"
  find "$CLAUDE_PROJECTS" -name '*.jsonl' -newer "$marker" 2>/dev/null | while read -r f; do
    proj="$(basename "$(dirname "$f")")"
    echo "- ${proj}: ${f}"
  done
  rm -f "$marker"
fi
echo

# ---- Evidence ticket IDs ----
echo "## Evidence ticket IDs"
if [ -s "$ticket_tmp" ]; then
  grep -oE '[A-Z][A-Z0-9]+-[0-9]+' "$ticket_tmp" 2>/dev/null | sort -u || true
fi
echo
