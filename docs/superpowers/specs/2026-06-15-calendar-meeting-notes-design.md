# Design: Calendar + meeting-notes capability for `summarizing-my-day`

**Date:** 2026-06-15
**Status:** Approved (pending spec review)

## Goal

Add an optional Google Calendar source to the `summarizing-my-day` skill that:

1. Lists the meetings the user attended in the window (context for the summary).
2. Finds the Google Doc notes attached to those meetings.
3. Extracts action items assigned to the user from those notes.
4. Collects action items from every source that produces them (meeting notes and Slack
   follow-ups) into a single unified `## Action Items` section in the daily note, each item
   tagged with its source. Nothing is auto-created anywhere.

## Architectural fit

Google Calendar and Google Drive are remote MCP sources, so they slot in exactly like the
existing Slack integration: an **optional, setup-gated** layer on top of the local
`gather.sh` output. No changes to `gather.sh` or its tests — all new logic lives in the
SKILL.md procedure as MCP calls. Calendar is enabled independently of Slack and JIRA and is
**not** part of the setup-complete test.

## Config additions

Add to `~/.claude/summarizing-my-day.json`:

```json
"calendar": { "enabled": false, "calendarId": "primary" }
```

- Opt-in, default `enabled: false` — same shape as `slack`.
- `calendarId` defaults to `"primary"`; setup asks only if the user has multiple calendars.

## Setup (new step, after the Slack step)

1. Ask: *"Include Google Calendar in summaries? Reads your accepted meetings in the window
   plus the Google Doc notes attached to those events."*
2. If yes → verify the Google Calendar MCP via `list_calendars` and resolve `calendarId`
   (default `primary`; if multiple calendars, ask which). Then check the Google Drive MCP is
   connected.
   - Calendar present, Drive present → `calendar.enabled = true`, store `calendarId`.
   - Calendar present, Drive absent → `calendar.enabled = true`, but warn that the meetings
     list will work while **notes/action-items will be skipped** until Drive is connected.
3. If no, or the Google Calendar MCP is absent → `calendar.enabled = false`.
4. Carry `lastRun` forward as the existing setup does.

## Procedure (new step, runs after the Slack step, before the JIRA step)

Only if `calendar.enabled`; otherwise skip silently. Also skip and note "Calendar skipped" if
the Calendar MCP is unavailable at run time.

1. `list_events` windowed `since`→now on `calendarId`.
2. **Filter to accepted meetings:** keep events where the user's `responseStatus` is
   `accepted` OR the user is the organizer, AND there is ≥1 other attendee. Drop all-day
   events, declined events, and solo/focus blocks.
3. For each kept meeting, `get_event` to read its **attachments**. For attached Google Docs,
   read the note via the Google Drive MCP (`read_file_content`). Per the matching decision,
   use **event attachments only** — no Drive title/date search fallback.
4. From each note, extract **action items assigned to the user** (their name / "Trevor" /
   clear first-person commitments), conservatively — when unsure, drop the item.
5. Harvest any JIRA ticket IDs found in the notes into the evidence-ticket set (same as the
   Slack step does), so they feed the JIRA step and synthesis.
6. Keep the labeled meetings list and the labeled action items for the output steps.

## Output

- **Meetings** → a short list folded into `## Work Summary` (which meetings the user
  attended, as context).
- **Action items** → a single managed section `## Action Items`, collecting items from every
  source that produces them (meeting notes and Slack follow-ups), each item carrying its
  source inline:

  ```
  ## Action Items
  - Send the migration timeline to Dana — *(meeting: Platform sync)*
  - Get the NYA PR up — *(Slack)*
  ```

- The existing **"Follow-ups (from Slack)"** line is **removed**; Slack follow-ups now route
  into this unified `## Action Items` section tagged `(Slack)`. The Slack-filtering wording is
  updated to reference the unified section.
- At the **STOP-and-present** step, surface the whole Action Items list alongside the summary
  for the user's review. **No auto-creation anywhere** — items are written to the note and
  flagged, nothing more. (This is independent of the existing JIRA confirm-gate, which is
  unchanged.)

## Daily-note rule changes

`## Action Items` becomes a managed section, handled with the same create/append discipline as
`## Work Summary`:

- File doesn't exist → create with the heading, then `## Work Summary`, then `## Action Items`
  (only if there are action items).
- File exists, `## Action Items` absent → append the section (only if there are action items).
- File exists, `## Action Items` present (earlier run today) → append new items under it; do
  not replace existing items.
- All other sections remain untouched. The "never overwrite / only touch managed sections"
  rule now covers both `## Work Summary` and `## Action Items`.

## Edge cases (mirroring Slack)

- `calendar.enabled` false / Calendar MCP unavailable → skip Calendar; note it.
- Drive unavailable but Calendar on → list meetings, skip notes/action-items, note it.
- No meetings in window → no Meetings list, no `## Action Items` section from meetings.
- No action items from any source → omit the `## Action Items` section entirely.
- Scheduled/headless runs → interactively-authenticated MCPs may be absent; skip gracefully
  exactly as Slack does.

## Out of scope (YAGNI)

- Drive title/date search fallback for notes (attachments-only by decision).
- Notion / Slite as note sources.
- Auto-creating JIRA tickets or Todoist tasks from action items.
- Bounded historical windows (existing window behavior is unchanged).

## Testing

No automated test changes — all new logic is MCP-driven in the procedure, not in `gather.sh`,
matching the existing Slack integration which also has no automated test. `tests/test_gather.sh`
is unaffected.

## Documentation

Update `README.md` to describe the optional Calendar/Drive source under "What it reads" and
the first-run setup, mirroring how Slack is documented.
