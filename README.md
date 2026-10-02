# summarizing-my-day

A Claude Code skill that reconstructs what you did since your last summary — from local git
history, shell history, and Claude Code session transcripts, plus your assigned JIRA activity
and (optionally) your Slack messages — writes a first-person summary into your Markdown daily
note, and proposes brief status comments on the tickets you worked. **It posts nothing to
Slack, and nothing to JIRA without your explicit confirmation.**

> **Scope:** This skill is built for software engineers. Its sources are the everyday developer
> toolset — git, shell, Claude Code, JIRA, and Slack — and it deliberately does **not** cover
> design tools (e.g. Figma) or project-/product-management apps beyond JIRA tickets.

## What it reads

The skill reads from these sources for the window:

- **Git** — `git log` (commits authored by your git email) and `git status` (uncommitted
  changes) in each git repo directly under your repos directory. *Source:* local git;
  directory defaults to `~/repos` (`gather.reposDir`), author defaults to your global
  `git config user.email` (`gather.gitEmail`).
- **Shell history** — commands you ran in the window. *Source:* your local zsh history file,
  default `~/.zsh_history` (`gather.histFile`); requires zsh `EXTENDED_HISTORY` (see
  Requirements).
- **Claude sessions** — which Claude Code transcripts you touched (by file modification time;
  the contents are read only as needed during synthesis). *Source:* local `*.jsonl` files
  under `~/.claude/projects` (`gather.claudeProjectsDir`).
- **JIRA** — your assigned-ticket activity (JQL `assignee = currentUser() AND updated >= …`)
  plus details for tickets referenced in the above. *Source:* the Atlassian MCP, using
  `jiraCloudId` from config (remote; skipped if empty).
- **Slack** *(optional, only if enabled in setup)* — your sent messages across all channel
  types and the DMs you received, filtered to work-related to-do items. *Source:* the Slack
  MCP, using your `slack.userId` (remote; reads DMs and private channels).
- **Google Calendar** *(optional, only if enabled in setup)* — your accepted meetings in the
  window, plus the Google Doc notes attached to those events (read via the Google Drive MCP).
  Used to add a Meetings list for context and to extract your to-do items. *Source:* the
  Google Calendar and Google Drive MCPs (remote; skipped if disabled or not connected).

The first three (git, shell, Claude transcripts) are gathered locally by `gather.sh` with no
network calls; JIRA, Slack, and Calendar are remote MCP queries. The skill writes only to the
`## Work Summary` and `## To-Do Items` sections of today's daily note, posts nothing to Slack,
and posts nothing to JIRA without your explicit confirmation.

## Install

Copy or clone this directory into your Claude Code skills folder:

```
~/.claude/skills/summarizing-my-day/
```

Then in Claude Code, run `/summarize` (or say "summarize my day").

## Requirements

- **zsh with extended history.** The shell-history source parses zsh's extended-history format
  (`: <epoch>:<duration>;<command>` lines), which requires `setopt EXTENDED_HISTORY` (default
  history file `~/.zsh_history`). Plain Bash history (`~/.bash_history`, no timestamps) is **not**
  supported — the "Shell commands" portion of the summary will be empty. Other sources (git,
  Claude transcripts, JIRA, Slack) work regardless of shell.

## First-run setup

The first run (or any run with an incomplete config) walks you through setup and saves
`~/.claude/summarizing-my-day.json`:

- **Daily-notes directory** — the folder holding your dated `YYYY-MM-DD.md` notes.
- **Sources** (optional) — override where it looks for repos, shell history, and Claude
  projects if yours differ from the defaults (`~/repos`, `~/.zsh_history`,
  `~/.claude/projects`).
- **JIRA cloud id** — resolved from your connected Atlassian MCP. If you have no Atlassian
  MCP, leave it empty and the skill runs in note-only mode (no JIRA).
- **Google Calendar** (optional) — enable to include your accepted meetings and their attached
  Google Doc notes. Requires the Google Calendar MCP (and the Google Drive MCP to read notes).
  Leave it off to skip calendar entirely.

To reconfigure later, say "reconfigure summarize".

## Choosing the time window

By default the summary covers everything **since your last run** (tracked as `lastRun` in the
config). You can override the window for a single run just by saying so when you invoke it —
no config change needed:

- `summarize today` → since midnight today
- `summarize my week` / `summarize since Monday` → since the start of the week
- `summarize since 2026-06-01` → since that date

The phrase sets the **start** of the window. A couple of behaviors to know:

- **The window always ends at "now."** Only the start is adjustable, so "today", "this week",
  and "since &lt;date&gt;" all work, but a bounded *historical* range (e.g. "*last* week only,"
  excluding this week) is not supported — every run reads through to the present.
- **Any run advances `lastRun` to now**, including an override run. So if you fire off a one-off
  weekly summary, your next plain "since last run" starts from that weekly run, not from where
  it would have otherwise. Override windows are ad-hoc, not a saved daily/weekly mode.


## To-Do items

When Slack or Calendar is enabled, the skill collects to-do items assigned to you — from
meeting notes and Slack follow-ups — into a single `## To-Do Items` section in the daily
note, each tagged with its source. They're written as Obsidian checkboxes so you can tick
them off in place:

```
## To-Do Items
- [ ] Send the migration timeline to Dana — *(meeting: Platform sync)*
- [ ] Get the NYA PR up — *(Slack)*
```

They're surfaced for your review; nothing is auto-created (no tickets, no tasks), and later
runs append new items without touching the boxes you've already checked.

## The JIRA confirm-gate

The skill drafts ticket comments and shows them to you in a table. Nothing is posted until
you explicitly say which to post. "Just post them" is not enough — you confirm the specific
tickets after seeing the drafts.
