# Calendar + Meeting-Notes Capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Commits:** The repo owner handles all commits. Do NOT run `git commit`, `git add`, or `git push`. End each task by reporting what changed; leave committing to the user.

**Goal:** Add an optional Google Calendar source to the `summarizing-my-day` skill that lists attended meetings, reads their attached Google Doc notes, extracts the user's action items, and consolidates action items from all sources into one `## Action Items` section in the daily note.

**Architecture:** Google Calendar and Google Drive are remote MCP sources layered on top of the local `gather.sh` output, mirroring the existing optional Slack integration — opt-in, setup-gated, and not part of the setup-complete test. All new logic is prose in `SKILL.md` (MCP-driven); `gather.sh` and its tests are untouched.

**Tech Stack:** Markdown skill definition (`SKILL.md`), `README.md`, JSON config (`~/.claude/summarizing-my-day.json`); MCP tools `Google_Calendar` (`list_calendars`, `list_events`, `get_event`) and `Google_Drive` (`read_file_content`).

---

## File Structure

- **Modify:** `/Users/tanderson/.claude/skills/summarizing-my-day/SKILL.md` — config schema, setup step, procedure step, Slack-filtering wording, daily-note rules, edge cases, common mistakes.
- **Modify:** `/Users/tanderson/.claude/skills/summarizing-my-day/README.md` — "What it reads" and "First-run setup" sections.
- **Unchanged:** `gather.sh`, `tests/test_gather.sh`, `scheduled-run.sh`.

There is no automated test suite for the MCP-driven prose (consistent with how Slack was added). Verification for each task is reading the edited section back and confirming the JSON example still parses.

---

### Task 1: Add `calendar` config to the schema

**Files:**
- Modify: `SKILL.md` — "Config & state" section (the JSON block and the bullet list after it).

- [ ] **Step 1: Add the `calendar` key to the JSON example**

In the `Single file` JSON block, add a `calendar` line after the `slack` line. The block becomes:

```json
{
  "version": 1,
  "dailyNotesDir": "",
  "noteFilename": "YYYY-MM-DD.md",
  "jiraCloudId": "",
  "gather": { "reposDir": "", "histFile": "", "claudeProjectsDir": "", "gitEmail": "" },
  "slack": { "enabled": false, "userId": "" },
  "calendar": { "enabled": false, "calendarId": "primary" },
  "lastRun": 0
}
```

- [ ] **Step 2: Add a bullet describing `calendar`**

Immediately after the existing `slack.enabled` bullet (the one ending "…NOT part of the setup-complete test."), add:

```markdown
- `calendar.enabled` is opt-in (default off); when on, `calendar.calendarId` holds the
  calendar to read (default `"primary"`). Calendar is optional and NOT part of the
  setup-complete test. Reading meeting notes also needs the Google Drive MCP.
```

- [ ] **Step 3: Verify**

Read the "Config & state" section back. Confirm the JSON block is valid JSON (the new line has a trailing comma before `"lastRun"`) and the new bullet sits alongside the `slack` bullet.

---

### Task 2: Add the Calendar setup step

**Files:**
- Modify: `SKILL.md` — "Setup (first run)" numbered list.

- [ ] **Step 1: Insert a new step 5 (Calendar) and renumber the trailing step**

The current step 4 is Slack; current step 5 writes the config. Insert a Calendar step between them so the order is: 4 Slack, 5 Calendar, 6 write config. Replace the existing step 5 ("Read the existing config first…") so it is renumbered to 6, and insert this new step 5 before it:

```markdown
5. **Google Calendar (optional)** — ask: "Include Google Calendar in summaries? This reads
   your accepted meetings in the window plus the Google Doc notes attached to those events,
   each run." If yes → call `list_calendars`. One calendar → use it; multiple → ask which;
   default `primary`. Set `calendar.enabled` true and `calendar.calendarId` to the chosen id.
   Then confirm the Google Drive MCP is connected: if it is not, keep `calendar.enabled` true
   but warn that the meetings list will work while notes/action-items are skipped until Drive
   is connected. If no, or the Google Calendar MCP is not connected → set `calendar.enabled`
   false.
```

- [ ] **Step 2: Confirm the renumbered config-write step still carries `lastRun` forward**

The renumbered step 6 must still read: write the full JSON with all fields (now including `calendar`) set from the user's answers, carrying `lastRun` forward. Update its text to mention `calendar` is among the saved fields:

```markdown
6. Read the existing config first if present and carry its `lastRun` forward; then write the
   full JSON with all fields set from the user's answers (including `slack` and `calendar`).
   Confirm a one-line summary of what was saved, then proceed into the Procedure.
```

- [ ] **Step 3: Verify**

Read the "Setup (first run)" section back. Confirm steps are sequential 1–6, Slack is 4, Calendar is 5, config-write is 6.

---

### Task 3: Add the Calendar procedure step

**Files:**
- Modify: `SKILL.md` — "Procedure" numbered list (insert after the Slack step, before the JIRA step) and renumber the rest.

- [ ] **Step 1: Insert the Calendar step as the new step 4 and renumber 4–10 → 5–11**

The current step 3 is Slack; current step 4 is "Pull JIRA activity". Insert this as the new step 4 and renumber every subsequent step (old 4→5, 5→6, … 10→11):

```markdown
4. **Google Calendar** — only if `calendar.enabled` (else skip silently; also skip and note
   "Calendar skipped" if the Calendar MCP is unavailable). Using `calendar.calendarId`:
   - `list_events` windowed `since`→now.
   - Keep **accepted meetings**: events where the user's `responseStatus` is `accepted` or
     the user is the organizer, AND there is ≥1 other attendee. Drop all-day events, declined
     events, and solo/focus blocks.
   - For each kept meeting, `get_event` and read its **attachments** only (no Drive title/date
     search). For each attached Google Doc, read it via the Google Drive MCP
     (`read_file_content`). If the Drive MCP is unavailable, list the meetings but skip notes
     and note "meeting notes skipped (Drive unavailable)".
   - From each note, extract **action items assigned to the user** (their name / "Trevor" /
     clear first-person commitments), conservatively — when unsure, drop the item. Tag each
     with its meeting title for the unified Action Items section (see "Action items").
   - Add any JIRA ticket IDs found in the notes to the evidence ticket IDs from steps 2–3.
   - Keep the labeled meetings list and action items for steps 6 and 9.
```

- [ ] **Step 2: Update the JIRA step's evidence-source wording**

The renumbered JIRA step (old step 4, now step 5) references "evidence ticket ID from the gather and Slack output". Update its `getJiraIssue` bullet to include Calendar:

```markdown
   - `getJiraIssue` for each evidence ticket ID from the gather, Slack, and meeting-note output.
```

- [ ] **Step 3: Update the Synthesize step to fold in meetings and action items**

The renumbered Synthesize step (old step 5, now step 6) ends with the Slack folding sentence. Append to it:

```markdown
   Fold the attended meetings into the summary as context (a short Meetings list under
   `## Work Summary`). Collect action items from meeting notes and Slack follow-ups into the
   unified `## Action Items` list (see "Action items"), each tagged with its source.
```

- [ ] **Step 4: Update the STOP-and-present step to surface action items**

The renumbered present step (old step 8, now step 9) currently shows the summary then the JIRA table. Add an instruction to also surface the Action Items list:

```markdown
   Also show the unified `## Action Items` list (all sources) for the user's review. These are
   written to the note and flagged only — never auto-created anywhere. This is separate from
   the JIRA confirm-gate below.
```

- [ ] **Step 5: Verify**

Read the "Procedure" section back. Confirm steps run 1–11, Calendar is step 4, the JIRA/Synthesize/present steps reference meetings + action items, and the final `lastRun`-write step is now step 11.

---

### Task 4: Add the unified Action Items output and daily-note rules

**Files:**
- Modify: `SKILL.md` — "Slack filtering" section, "Daily note" section, and add an "Action items" subsection.

- [ ] **Step 1: Update "Slack filtering" to route follow-ups into the unified section**

In the "Slack filtering" section, the **"Work commitment or open todo"** bullet currently routes to a `"Follow-ups (from Slack)"` line under `## Work Summary`. Replace that bullet with:

```markdown
- **Work commitment or open todo** (e.g. "I'll get the NYA PR up today"; a request the user
  clearly accepted or acted on) → add to the unified **`## Action Items`** section (see
  "Action items"), tagged `(Slack)`.
```

- [ ] **Step 2: Add an "Action items" subsection after "Slack filtering"**

Insert a new section immediately after "Slack filtering" and before "Daily note":

```markdown
## Action items

A single `## Action Items` section in the daily note collects action items from **every**
source — meeting notes, Slack follow-ups, and JIRA-referenced todos — with the source tagged
inline. Extract conservatively; when unsure whether an item is the user's, drop it. Format:

\`\`\`
## Action Items
- Send the migration timeline to Dana — *(meeting: Platform sync)*
- Get the NYA PR up — *(Slack)*
- Add repro steps to PROJ-481 — *(JIRA)*
\`\`\`

Items are written to the note and surfaced at the STOP-and-present step for review. They are
never auto-created anywhere (no JIRA tickets, no Todoist tasks). If there are no action items
from any source, omit the section entirely.
```

(Note: in the actual file, the fenced example uses plain triple backticks — the escaping above is only for this plan document.)

- [ ] **Step 3: Extend the "Daily note" rules to cover `## Action Items`**

In the "Daily note" section, the rule currently says only `## Work Summary` is managed. Replace the bullet:

```markdown
- Never overwrite the file or touch sections other than `## Work Summary`.
```

with:

```markdown
- Never overwrite the file or touch sections other than the managed sections
  `## Work Summary` and `## Action Items`.
```

Then add these `## Action Items` rules at the end of the "Daily note" bullet list:

```markdown
- **`## Action Items`** is managed with the same discipline as `## Work Summary`, and only
  written when there are action items:
  - File/section absent → create/append the `## Action Items` section.
  - Section present (earlier run today) → append new items under it; do not replace existing
    items.
  - When creating a brand-new file, order the sections: title, then `## Work Summary`, then
    `## Action Items`.
```

- [ ] **Step 4: Verify**

Read the "Slack filtering", "Action items", and "Daily note" sections back. Confirm there is no remaining reference to a separate "Follow-ups (from Slack)" line, the Action Items example renders with real backticks, and both managed sections are named in the never-overwrite rule.

---

### Task 5: Update edge cases and common mistakes

**Files:**
- Modify: `SKILL.md` — "Edge cases" and "Common mistakes" lists.

- [ ] **Step 1: Add Calendar edge cases**

In the "Edge cases" list, after the `slack.enabled false …` bullet, add:

```markdown
- `calendar.enabled` false / Google Calendar MCP unavailable → skip Calendar; note it.
- Calendar on but Google Drive MCP unavailable → list meetings, skip notes/action-items; note it.
- No accepted meetings in window → no Meetings list and no meeting-sourced action items.
- No action items from any source → omit the `## Action Items` section entirely.
```

- [ ] **Step 2: Add Calendar common mistakes**

In the "Common mistakes" list, add:

```markdown
- Including declined/all-day/solo calendar events → keep only accepted meetings with attendees.
- Listing action items not assigned to the user → extract conservatively; drop if unsure.
- Auto-creating tasks/tickets from action items → only write them to the note and surface them.
```

- [ ] **Step 3: Verify**

Read the "Edge cases" and "Common mistakes" sections back. Confirm the new bullets are present and consistent with the procedure.

---

### Task 6: Update the README

**Files:**
- Modify: `README.md` — "What it reads" list and "First-run setup" list.

- [ ] **Step 1: Add Calendar to "What it reads"**

After the **Slack** bullet in the "What it reads" list, add:

```markdown
- **Google Calendar** *(optional, only if enabled in setup)* — your accepted meetings in the
  window, plus the Google Doc notes attached to those events (read via the Google Drive MCP).
  Used to add a Meetings list for context and to extract your action items. *Source:* the
  Google Calendar and Google Drive MCPs (remote; skipped if disabled or not connected).
```

Then update the paragraph that begins "The first three (git, shell, Claude transcripts) are gathered locally…" so the remote-sources sentence reads:

```markdown
The first three (git, shell, Claude transcripts) are gathered locally by `gather.sh` with no
network calls; JIRA, Slack, and Calendar are remote MCP queries.
```

- [ ] **Step 2: Add Calendar to "First-run setup"**

After the **JIRA cloud id** bullet in "First-run setup", add:

```markdown
- **Google Calendar** (optional) — enable to include your accepted meetings and their attached
  Google Doc notes. Requires the Google Calendar MCP (and the Google Drive MCP to read notes).
  Leave it off to skip calendar entirely.
```

- [ ] **Step 3: Note the unified Action Items output**

After the "Choosing the time window" or near the end of the README's behavior description, add a short note (place it as its own short section before "The JIRA confirm-gate"):

```markdown
## Action items

When Slack or Calendar is enabled, the skill collects action items assigned to you — from
meeting notes and Slack follow-ups — into a single `## Action Items` section in the daily
note, each tagged with its source. They're written to the note and surfaced for your review;
nothing is auto-created (no tickets, no tasks).
```

- [ ] **Step 4: Verify**

Read `README.md` back. Confirm Calendar appears in "What it reads" and "First-run setup", the remote-sources sentence lists Calendar, and the new "Action items" section is present.

---

## Self-Review

**Spec coverage:**
- Config additions → Task 1. ✔
- Setup step → Task 2. ✔
- Procedure (list_events, accepted-meeting filter, attachments-only, action-item extraction, JIRA-ID harvest) → Task 3. ✔
- Meetings folded into Work Summary; unified Action Items; Slack follow-ups folded in → Tasks 3 & 4. ✔
- Daily-note managed-section rules → Task 4. ✔
- Edge cases (mirroring Slack) → Task 5. ✔
- README documentation → Task 6. ✔
- Testing: no automated test changes (stated in header & File Structure). ✔
- Out-of-scope items (Drive search fallback, Notion/Slite, auto-creation) → not implemented; reinforced by Task 5 common-mistakes bullets. ✔

**Placeholder scan:** No TBD/TODO; every edit shows the exact final text. ✔

**Type/name consistency:** `calendar.enabled` / `calendar.calendarId`, section name `## Action Items`, source tags `(meeting: …)` / `(Slack)` / `(JIRA)`, and MCP tool names (`list_calendars`, `list_events`, `get_event`, `read_file_content`) are used consistently across Tasks 1–6. ✔
