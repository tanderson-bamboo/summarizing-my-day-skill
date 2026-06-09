#!/usr/bin/env bash
# Self-contained tests for gather.sh. No network, no real data — temp fixtures only.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATHER="$SKILL_DIR/gather.sh"
# Ensure scripts are executable (idempotent)
chmod +x "$GATHER" "$0" 2>/dev/null || true
fail=0

assert_contains() { # haystack needle msg
  # Use grep on a heredoc to avoid SIGPIPE under pipefail when haystack is large.
  if grep -qF -- "$2" <<< "$1"; then echo "ok: $3"; else echo "FAIL: $3 (missing: '$2')"; fail=1; fi
}
assert_not_contains() { # haystack needle msg
  if grep -qF -- "$2" <<< "$1"; then echo "FAIL: $3 (unexpected: '$2')"; fail=1; else echo "ok: $3"; fi
}
assert_exit() { # actual expected msg
  if [ "$1" = "$2" ]; then echo "ok: $3"; else echo "FAIL: $3 (exit $1, expected $2)"; fail=1; fi
}

# --- Task 2: arg handling ---
test_args() {
  "$GATHER" >/dev/null 2>&1; assert_exit "$?" "2" "missing --since exits 2"
  local out; out="$("$GATHER" --since 1000000000 2>/dev/null)"
  assert_contains "$out" "# Activity since" "header printed with --since"
}

test_args

test_git() {
  local root out
  root="$(mktemp -d)"
  mkdir -p "$root/repoA"
  git -C "$root/repoA" init -q
  git -C "$root/repoA" config user.email "me@example.com"
  git -C "$root/repoA" config user.name "Me"
  git -C "$root/repoA" checkout -q -b "tanderson/BUGS-99999-thing"
  echo old > "$root/repoA/a.txt"; git -C "$root/repoA" add -A
  GIT_AUTHOR_DATE="2001-01-01T00:00:00" GIT_COMMITTER_DATE="2001-01-01T00:00:00" \
    git -C "$root/repoA" commit -q -m "OLD do not include"
  echo new > "$root/repoA/a.txt"; git -C "$root/repoA" add -A
  git -C "$root/repoA" commit -q -m "TACO-1234 add new thing"
  echo wip > "$root/repoA/b.txt"

  out="$(SUMMARIZE_REPOS_DIR="$root" SUMMARIZE_GIT_EMAIL="me@example.com" "$GATHER" --since 1100000000)"
  assert_contains "$out" "## Git commits" "git section present"
  assert_contains "$out" "TACO-1234 add new thing" "new commit included"
  assert_not_contains "$out" "OLD do not include" "old commit excluded"
  assert_contains "$out" "## Uncommitted changes" "uncommitted section present"
  assert_contains "$out" "b.txt" "uncommitted file shown"
  rm -rf "$root"
}

test_git

test_shell() {
  local hf out
  hf="$(mktemp)"
  {
    printf ': 1000000000:0;OLD_CMD_before_window\n'
    # Non-UTF8 byte (0x80) in an out-of-window entry: macOS awk aborts on this
    # unless run byte-safe (LC_ALL=C), which would drop all later in-window commands.
    printf ': 1000000001:0;bad_byte_\x80_here\n'
    printf ': 1200000000:0;NEW_CMD_in_window\n'
    printf ': 1200000050:0;multiline_start \\\n'
    printf 'continued_line\n'
  } > "$hf"
  out="$(SUMMARIZE_HISTFILE="$hf" "$GATHER" --since 1100000000)"
  assert_contains "$out" "## Shell commands" "shell section present"
  assert_contains "$out" "NEW_CMD_in_window" "in-window command included"
  assert_not_contains "$out" "OLD_CMD_before_window" "out-of-window command excluded"
  assert_contains "$out" "multiline_start \\" "multiline leading line included for in-window cmd"
  assert_contains "$out" "continued_line" "multiline continuation included for in-window cmd"
  rm -f "$hf"
}

test_shell

test_claude() {
  local proj out
  proj="$(mktemp -d)"
  mkdir -p "$proj/-Users-me-repos-main"
  touch "$proj/-Users-me-repos-main/recent.jsonl"
  touch -t 200101010000.00 "$proj/-Users-me-repos-main/old.jsonl"
  out="$(SUMMARIZE_CLAUDE_PROJECTS="$proj" "$GATHER" --since 1100000000)"
  assert_contains "$out" "## Claude sessions" "claude section present"
  assert_contains "$out" "recent.jsonl" "recent transcript listed"
  assert_not_contains "$out" "old.jsonl" "old transcript excluded"
  rm -rf "$proj"
}

test_claude

test_tickets() {
  local root out
  root="$(mktemp -d)"
  mkdir -p "$root/repoA"
  git -C "$root/repoA" init -q
  git -C "$root/repoA" config user.email "me@example.com"
  git -C "$root/repoA" config user.name "Me"
  git -C "$root/repoA" checkout -q -b "tanderson/BUGS-99999-thing"
  echo x > "$root/repoA/a.txt"; git -C "$root/repoA" add -A
  git -C "$root/repoA" commit -q -m "TACO-1234 add new thing"
  out="$(SUMMARIZE_REPOS_DIR="$root" SUMMARIZE_GIT_EMAIL="me@example.com" "$GATHER" --since 1100000000)"
  assert_contains "$out" "## Evidence ticket IDs" "ticket section present"
  assert_contains "$out" "TACO-1234" "ticket from commit message extracted"
  assert_contains "$out" "BUGS-99999" "ticket from branch name extracted"
  rm -rf "$root"
}

test_tickets

test_flags() {
  local root hf out
  root="$(mktemp -d)"
  hf="$(mktemp)"
  mkdir -p "$root/repoA"
  git -C "$root/repoA" init -q
  git -C "$root/repoA" config user.email "flag@example.com"
  git -C "$root/repoA" config user.name "Flag"
  git -C "$root/repoA" checkout -q -b "x/FLAG-1-thing"
  echo x > "$root/repoA/a.txt"; git -C "$root/repoA" add -A
  git -C "$root/repoA" commit -q -m "FLAG-1 via flags"
  printf ': 1200000000:0;CMD_via_flag\n' > "$hf"

  # Pass everything via CLI flags (no SUMMARIZE_* env vars).
  out="$("$GATHER" --since 1100000000 \
    --repos-dir "$root" --git-email "flag@example.com" --histfile "$hf")"
  assert_contains "$out" "FLAG-1 via flags" "commit found via --repos-dir/--git-email flags"
  assert_contains "$out" "CMD_via_flag" "shell cmd found via --histfile flag"
  rm -rf "$root" "$hf"
}

test_flags

[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit "$fail"
