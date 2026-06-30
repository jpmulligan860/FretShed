# TestFlight Beta — "What to Test" (Task 5.16)

> Paste the **Tester-Facing Note** section into App Store Connect → TestFlight → Test Details → "What to Test."
> The rest of this file is internal: tester recruiting, the testing matrix, and how to triage feedback.

---

## Tester-Facing Note (paste into TestFlight)

Welcome to the FretShed beta — thanks for helping shape the app before launch!

FretShed helps you memorize the notes across your guitar fretboard. It listens to you play through your mic or audio interface, calibrates to your guitar and room, and adapts each practice session to your weak spots.

**Please run through these flows and tell us what felt off:**

1. **First launch / onboarding** — Did the intro make sense? Was the mic-permission explanation clear before the system prompt appeared?
2. **Audio calibration** — Run the calibration (silence + all 6 open strings). Did it detect each string? Did naming/saving the profile work? Try re-calibrating too.
3. **Tuner** — Tune each string. Is the reading stable as the note rings out, and does it respond when you turn a peg? Try both your built-in mic and an audio interface if you have one. Note your guitar type (electric/acoustic) and input method in feedback.
4. **A practice session** — Launch Smart Practice and play through a session. Were notes detected reliably? Any missed notes, false triggers, or "stuck" detection? Did the difficulty feel adaptive?
5. **Tap mode** — In a session, switch to Tap-to-Answer and confirm you can practice without audio.
6. **Metronome + Drone** — Start the metronome, change BPM/time signature/subdivision, try the speed trainer. Does the click stay steady? Try the drone tone.
7. **Progress / Journey tab** — After a session, check that your stats, heatmap, and session history updated.
8. **Going Premium (sandbox)** — Tap a locked feature (e.g. a premium focus mode or strings 1–3). The paywall should appear. *Use your Sandbox tester account* — purchases are free in TestFlight. Confirm the lock disappears after "purchase" and stays unlocked after you relaunch.

**What's most useful to report:**
- Your device model, guitar type, and input method (built-in mic vs. interface)
- Any missed/wrong/stuck note detection — and which string/fret
- Tuner accuracy vs. a tuner you trust
- Anything that crashed, froze, looked broken, or confused you
- Any text/copy that read awkwardly

Use the in-app TestFlight feedback (screenshot + note) or reply to the invite email. Thank you! 🎸

---

## Internal — Beta Plan (Tasks 5.17–5.18)

### Recruiting (5.17) — target 20–30 testers
- **Incentive:** 3 months free Premium at launch for active beta testers.
- **Channels:** personal guitar contacts, local teachers/students, r/guitarlessons + r/learnguitar (follow subreddit self-promo rules — participate first, no spam), any email list signups from fretshed.com.
- **Spread coverage across:** electric + acoustic (+ classical if possible); built-in mic + USB/Lightning interface; a range of skill levels (true beginner → intermediate); device sizes (SE, standard, Pro Max).
- Collect emails → add as Internal/External testers in App Store Connect.

### Beta run (5.18) — 2–3 weeks
1. Upload build (5.15), enable the beta group, send invites with the note above.
2. Watch TelemetryDeck for funnel drop-off (onboarding → calibration → first session → paywall).
3. Triage feedback into BUGLOG.md as it arrives — tag P0 (crash/blocker), P1 (broken flow), P2 (polish).
4. Fix the **top 3 issues**, re-archive, push a new build to the same group.
5. Confirm fixes with testers before moving to final submission (5E).

### Coverage matrix to fill during beta
| Tester | Device | Guitar type | Input | Onboarding | Calibration | Tuner | Quiz detect | Paywall | Notes |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | |

### Exit criteria before submission (5.23)
- Zero known P0/P1 issues.
- Detection + tuner validated on at least 3 guitars and both input methods.
- Sandbox purchase flow (monthly, annual, lifetime, restore) verified by ≥2 testers.
- Final full test suite green (5.19) + clean device smoke test (5.20).
