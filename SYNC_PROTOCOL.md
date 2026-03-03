# FretShed — Sync Protocol

> **This file is shared by both Claude.ai and Claude Code.** Either side can read it but neither should edit it without coordinating with the user. Add it to both the Claude.ai Project Knowledge and the Claude Code project root.

---

## The Problem

FretShed uses two interfaces with separate file ownership:

| File | Owned by | The other side… |
|---|---|---|
| `CLAUDE.md` | Claude Code | Claude.ai reads only |
| `CLAUDE_STRATEGY.md` | Claude.ai | Claude Code reads only |
| `ROADMAP.md` | Claude Code | Claude.ai reads only |
| `ROADMAP_STRATEGY.md` | Claude.ai | Claude Code reads only |
| `TEAM_OF_EXPERTS.md` | Either | Both read, coordinate edits |
| `SYNC_PROTOCOL.md` | Shared | Both read only |

Because files can't transfer automatically, the user (John) is the bridge. This protocol makes that painless.

---

## How It Works: The Sync Ledger

Each owned file has a **sync ledger** — a small section at the bottom that tracks two things:

1. **Outbound changes** — "I changed something the other side needs to know about"
2. **Inbound requests** — "The other side needs me to change something in my files"

### Format

At the bottom of each owned file, maintain this section:

```markdown
## Sync Ledger

### Outbound (changes the other side needs)
| Date | What Changed | Target | Status |
|---|---|---|---|
| 2026-03-03 | Updated Task 5.6 text | Claude.ai to note | ✅ Synced |

### Inbound (changes requested by the other side)
| Date | Change Requested | Source | Status |
|---|---|---|---|
| 2026-03-03 | Change Carrd → WordPress in Task 5.6 | ROADMAP_STRATEGY.md | ✅ Applied |
```

**Status values:** 🔲 Pending · ✅ Synced/Applied

---

## The "Sync Me" Command

When John says **"sync me"** to either interface, that interface runs this checklist:

### If you're Claude.ai:

1. **Check my outbound ledger** — Do any of my files (CLAUDE_STRATEGY.md, ROADMAP_STRATEGY.md) have pending outbound changes for Claude Code?
2. **Check for unprocessed inbound** — Did Claude Code request changes that I haven't applied yet?
3. **Generate a sync report:**

```
📋 SYNC REPORT (Claude.ai → Claude Code)

OUTBOUND (Claude Code needs to apply):
- [ ] ROADMAP.md Task 5.6: Change Carrd → WordPress
- [ ] ROADMAP.md Task 4.13: Add two telemetry events

INBOUND (I need updated files from Claude Code):
- [ ] Need latest ROADMAP.md (Claude Code updated Phase 4)

FILES TO RE-UPLOAD TO CLAUDE.AI PROJECT:
- (none pending)

PASTE THIS TO CLAUDE CODE:
> "Apply these sync items from ROADMAP_STRATEGY.md: [list]. Then mark them ✅ in your Sync Ledger as applied."
```

### If you're Claude Code:

1. **Check my outbound ledger** — Do any of my files (CLAUDE.md, ROADMAP.md) have pending outbound changes for Claude.ai?
2. **Check for unprocessed inbound** — Did Claude.ai request changes that I haven't applied yet?
3. **Generate a sync report:**

```
📋 SYNC REPORT (Claude Code → Claude.ai)

OUTBOUND (Claude.ai needs to know):
- [ ] ROADMAP.md: Completed Tasks 4.8-4.12
- [ ] CLAUDE.md: Added new architecture section

INBOUND (I need to apply):
- [ ] ROADMAP_STRATEGY.md requested Task 5.6 text change → Applied ✅

FILES FOR JOHN TO RE-UPLOAD TO CLAUDE.AI:
- ROADMAP.md (changed this session)
- CLAUDE.md (changed this session)

PASTE THIS TO CLAUDE.AI:
> "Claude Code completed Tasks 4.8-4.12 in ROADMAP.md. I've uploaded the latest ROADMAP.md. Please review and update any strategy references."
```

---

## Session Start & End Protocols

### Starting a session (either side)

Add this to existing session-start checklists:

> **Sync check:** Scan the Sync Ledger in my owned files. Are there any 🔲 Pending inbound items? If yes, flag them to John before starting new work.

### Ending a session (either side)

Add this to existing session-end protocols:

> **Sync check:** Did I change any files this session? If yes:
> 1. Log outbound changes in my Sync Ledger
> 2. Tell John which files need to be re-uploaded/shared with the other interface
> 3. If there are pending items for the other side, give John a ready-to-paste prompt

---

## Quick Reference: Who Uploads What

| Scenario | John does this |
|---|---|
| Claude Code changed ROADMAP.md or CLAUDE.md | Upload new version to Claude.ai Project Knowledge (replace old one) |
| Claude.ai changed ROADMAP_STRATEGY.md or CLAUDE_STRATEGY.md | Download the file, then add to Claude Code project root (or tell Claude Code to read it) |
| Either side changed TEAM_OF_EXPERTS.md | Upload/sync to the other side |
| Cross-file update needed | The requesting side logs it in Sync Ledger → John says "sync me" on the other side → that side applies it |

---

## Migration: Replacing the Old Cross-File Updates Section

The "Cross-File Updates Needed" section at the bottom of `ROADMAP_STRATEGY.md` is replaced by the Sync Ledger system. Existing pending items should be migrated to the ledger format.

The same applies to Claude Code's session-end reminder about re-uploading files — that behavior continues, but now also includes logging to the Sync Ledger.
