# Tuner Fix — Claude Code Review of Implementation Prompt

## Overall Assessment

The core diagnosis is correct: **smoothing biased data produces smooth bias.** The tuner fast path (lines 1310–1323 of PitchDetector.swift) skips crest factor and harmonic regularity checks that the quiz path uses, allowing degraded decay-phase frames through. The fix should be to **reject bad frames at the tap level**, not smooth them in the consumer. The quiz path already proves the full signal chain works without drift.

---

## Step-by-Step Review

### Step 1 — Revert the tuner fast path
**AGREE. This is the most important change.**

The tuner currently skips crest factor and harmonic regularity, using only spectral flatness. The quiz path uses a three-way tonal signal check (`crestFactor < 2.0 || harmonicReg > 0.3 || flatness < threshold`) and doesn't drift. Making the tuner use the identical signal chain is low-risk since the quiz already validates it across all strings and input sources.

### Step 2 — Raise confidence floor from 0.51 to 0.78
**AGREE WITH CAUTION.**

The current floor of 0.51 (60% of 0.85) was set specifically to let decay-phase frames through — which is exactly what causes drift. Raising it will reject those frames. However, this may cause the needle to "go silent" sooner during decay. The 1.5s hold window should bridge that gap, but device testing is needed to confirm. If the note cuts off too early on USB interfaces (where the signal decays slowly through a "mediocre confidence" zone), we may need to tune the multiplier (e.g., 0.85 instead of 0.78).

### Step 3 — 3-state machine (LISTENING/MEASURING/HOLDING)
**PARTIALLY AGREE — suggest modifying rather than rewriting.**

The existing 2-state machine (acquiring/tracking) already handles most of the proposed behavior:
- `acquiring` ≈ LISTENING (building consecutive gate, establishing note)
- `tracking` ≈ MEASURING (publishing directly, skipping gate)
- The hold window already provides HOLDING behavior (freeze on silence)

The key changes that matter are:
1. Replace adaptive EMA (`alpha=0.05/0.30`) with a plain 7-frame median — this removes the smoothed bias entirely
2. Drop the `smoothedCents` variable — publish the median directly
3. Remove DecayStabilizer integration (already done)

I'd implement these as modifications to the existing state machine rather than a full rewrite. This preserves the working infrastructure (confidence hysteresis, note change detection, attack stabilization) and reduces the risk of introducing new bugs. A full rewrite of the consumer loop has high regression risk — there are many edge cases already handled (attack transients, note changes mid-decay, silence gaps, hold timing) that would need to be re-implemented.

### Step 4 — Simplify TunerDisplayEngine
**PARTIALLY AGREE.**

Removing the input EMA (`inputAlpha=0.4`) makes sense — the consumer already applies a median filter, so the double-smoothing is redundant. But the spring-damper gain schedule (coarse 300/35, fine 200/30, precision 80/22) provides professional-feeling needle physics and should be kept. It's not contributing to the drift problem — it's just animating the already-processed value.

Suggestion: Set `inputAlpha = 1.0` (passthrough) or bypass the EMA entirely, but keep the spring-damper as-is.

### Step 5 — Integer cents display
**DISAGREE.**

Sub-cent precision (`%+.1f ¢`) was a Phase 1 improvement and provides useful information for fine tuning. The drift fix should come from rejecting bad frames at the signal level, not from rounding the display. If the underlying data is stable (which it should be after steps 1–2), sub-cent display helps users see fine peg adjustments. Rounding to integers would mask the fix's effectiveness and make the tuner feel less precise than competitors.

### Step 6 — Delete DecayStabilizer
**AGREE.**

DecayStabilizer.swift and DecayStabilizerTests.swift are unused. The locking approach was abandoned after 4 iterations proved it couldn't handle the fundamental tradeoff between drift suppression and peg turn response. Clean removal.

### Step 7 — Verify
**AGREE.**

Full test suite must pass. Device testing checklist is good.

---

## Recommended Implementation Strategy

**Incremental rather than all-at-once.** The prompt proposes 7 steps as a single implementation. I recommend a two-phase approach:

### Phase A: Fix the root cause (Steps 1 + 2)
1. Make the tuner tap path use the full quiz signal chain (three-way tonal gate)
2. Raise the confidence floor multiplier (from 0.60 to ~0.90, giving floor ≈ 0.765)
3. Build and device test

**Why stop here first:** These two changes address the root cause (bad frames passing through). If the drift is fixed at the tap level, the consumer may not need aggressive changes. Device testing will tell us whether the note cuts off too early (hold window insufficient) or whether further consumer simplification is needed.

### Phase B: Consumer cleanup (Steps 3 + 4 + 6), only if needed
4. Replace adaptive EMA with plain 7-frame median in tracking mode
5. Remove input EMA from TunerDisplayEngine
6. Delete DecayStabilizer files
7. Device test again

**Why conditional:** If Phase A alone fixes the drift (which is likely given that the quiz path already works), Phase B becomes an optimization pass rather than a critical fix. Over-engineering the consumer changes could introduce new problems (e.g., 7-frame median adding latency to peg turn response) that we'd then need to debug.

---

## Key Risk

The biggest risk is that the full signal chain + higher confidence floor causes the tuner to **drop out too early during decay** — the note disappears before the user finishes tuning. USB interfaces are the worst case: the signal decays slowly through a zone where it's too weak for the full tonal gate but hasn't fully decayed. The hold window (1.5s) bridges short gaps, but a sustained period of sub-threshold confidence could cause repeated drop-in/drop-out behavior.

Mitigation: Device test after Phase A. If dropout is a problem, we can:
- Lower the confidence multiplier slightly (0.85 instead of 0.90)
- Extend the hold window (2.0s instead of 1.5s)
- Keep the consumer confidence hysteresis at 0.55 for sustain mode (already in place)

---

## Summary of Disagreements

| Step | Prompt says | Claude Code says | Reason |
|------|-------------|------------------|--------|
| 3 | Full 3-state rewrite | Modify existing 2-state | Lower regression risk, same outcome |
| 4 | Remove spring-damper gain schedule | Keep spring-damper, remove input EMA only | Spring physics isn't causing drift |
| 5 | Integer cents display | Keep sub-cent `%+.1f ¢` | Drift fix should be at signal level, not display level |
| Order | All 7 steps at once | Phase A (1-2) → device test → Phase B (3-4-6) | Root cause fix may be sufficient alone |
