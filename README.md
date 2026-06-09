# summarizing-my-day

A Claude Code skill that reconstructs what you did since your last summary — from local git
history, shell history, and Claude Code session transcripts — plus your assigned JIRA
activity, writes a first-person summary into your Markdown daily note, and proposes brief
status comments on the tickets you worked. **It never posts to JIRA without your explicit
confirmation.**

## Install

Copy or clone this directory into your Claude Code skills folder:

```
~/.claude/skills/summarizing-my-day/
```

Then in Claude Code, run `/summarize` (or say "summarize my day").

## First-run setup

The first run (or any run with an incomplete config) walks you through setup and saves
`~/.claude/summarizing-my-day.json`:

- **Daily-notes directory** — the folder holding your dated `YYYY-MM-DD.md` notes.
- **Sources** (optional) — override where it looks for repos, shell history, and Claude
  projects if yours differ from the defaults (`~/repos`, `~/.zsh_history`,
  `~/.claude/projects`).
- **JIRA cloud id** — resolved from your connected Atlassian MCP. If you have no Atlassian
  MCP, leave it empty and the skill runs in note-only mode (no JIRA).

To reconfigure later, say "reconfigure summarize".

## What it reads (transparency)

`gather.sh` reads only local data: `git log`/`git status` in your repos directory, your shell
history file, and the modification times of your Claude session transcripts. It makes no
network calls and never writes to your notes or JIRA. The skill writes to a single section
(`## Work Summary`) of today's daily note and leaves the rest of the file untouched.

## The JIRA confirm-gate

The skill drafts ticket comments and shows them to you in a table. Nothing is posted until
you explicitly say which to post. "Just post them" is not enough — you confirm the specific
tickets after seeing the drafts.
