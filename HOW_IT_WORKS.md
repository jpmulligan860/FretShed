# FretShed — How It Works

> This document explains FretShed's three core technical systems in plain language: pitch detection, audio calibration, and adaptive learning. It's intended as a reference for strategy, content, and marketing work — for implementation details, see `CLAUDE.md`.

---

## Part 1: Pitch Detection

Here's how FretShed figures out what note you're playing:

**1. Listening** — The iPhone mic captures raw audio 44,100 times per second. Every ~23 milliseconds, a chunk of audio arrives for analysis.

**2. Filtering out rumble** — A high-pass filter removes everything below 60 Hz (room vibrations, air conditioning hum, handling noise). Guitar's lowest note (low E) is 82 Hz, so nothing useful is lost. This cutoff also supports drop D tuning, where the lowest note (D2) is 73.4 Hz.

**3. Is anyone playing?** — A noise gate checks if the sound is loud enough to be a guitar note vs. background silence. If it's too quiet, the system waits.

**4. Volume leveling** — Auto-gain control adjusts the signal to a consistent loudness. Whether you're playing softly or strumming hard, the analysis sees a normalized signal. This also adapts to different mic distances and guitar volumes.

**5. Boosting bass strings** — iPhone mics are physically tiny and naturally weak at low frequencies. An input-source-aware low-shelf boost compensates for this: +6 dB for built-in mic, +3.5 dB for wired headset, off for USB interfaces (which don't need it). This makes wound strings (E, A, D) register as strongly as treble strings.

**6. Removing background noise** — During silent moments, the system learns what your room's background noise "looks like" (frequency by frequency) using adaptive spectral subtraction. When you play, it subtracts that noise fingerprint from the signal — like noise cancellation headphones but for pitch detection. This extends usable detection from "quiet room" to "room with background noise."

**7. Is this a musical note or just noise?** — Three checks run in parallel, and any one passing is enough:
   - **Spectral flatness** — A guitar note has energy concentrated at specific frequencies (harmonics). Random noise has energy spread evenly everywhere. If the energy is too evenly spread, it's rejected as noise (like string slides or pick scrapes). The threshold is input-source-aware: relaxed to 0.50 for USB interfaces (where distortion pedals are common) vs. 0.35 for mic/headset.
   - **Crest factor** — Measures how "peaky" vs. "squashed" the signal is. A distorted guitar signal through a pedal looks squashed (clipped), which would normally look like noise. If the crest factor is below 2.0, it's recognized as intentional distortion and bypasses the flatness gate.
   - **Harmonic regularity** — Checks if energy peaks are evenly spaced (at 1x, 2x, 3x, 4x the fundamental frequency). Real notes — clean or distorted — always have this pattern. Noise doesn't. If the harmonic-to-total power ratio exceeds 0.3, the signal is accepted as tonal.

**8. Finding the pitch (YIN algorithm)** — This is the core. The algorithm asks: "If I shift this waveform forward in time, at what delay does it look most like itself?" That delay corresponds to the fundamental frequency. A sound wave at 110 Hz (A string) repeats every 1/110th of a second, so the algorithm finds a strong self-similarity at that delay. This is done using the Accelerate framework (Apple's optimized math library) for speed.

**9. Octave verification (HPS)** — The YIN algorithm sometimes picks up the 2nd harmonic instead of the fundamental (hearing A4 instead of A3). A second algorithm called Harmonic Product Spectrum cross-checks by multiplying the frequency spectrum with compressed copies of itself — the true fundamental "wins" because all harmonics line up there. If YIN and HPS disagree by an octave, the system corrects down.

**10. Confidence check** — YIN produces a confidence score (0–1). The threshold varies by context: the quiz requires high confidence (0.85) to avoid false answers, while the tuner uses a lower threshold (0.51) to maintain sustain display as a note decays.

**11. Smoothing** — A median filter removes one-off glitches (like a single weird frame in the middle of a held note).

**12. String-aware filtering (quiz only)** — During a quiz, the system knows which string you should be playing on. It only accepts frequencies within that string's range (±1 semitone tolerance), rejecting sympathetic vibrations from other strings.

**13. Consecutive frame check** — The same note must be detected 3 frames in a row (~70ms) before it's shown. This prevents momentary blips from registering as answers.

**14. Display** — The confirmed note name appears on screen (or is scored correct/incorrect in quiz mode). The tuner additionally uses confidence hysteresis — once a note is established, it accepts lower confidence to extend sustain display, preventing the needle from dropping while a note is still ringing.

The whole chain from mic input to note display takes roughly 70–100ms — fast enough to feel instantaneous while playing.

---

## Part 2: Audio Calibration

**Why calibrate at all?**

Every room sounds different — a bedroom is quieter than a living room with a TV on. Every guitar sounds different — a nylon classical guitar is much quieter than a steel-string acoustic. And every phone picks up sound slightly differently depending on its case, angle, and distance from the guitar. Calibration measures your specific setup once so the app doesn't have to guess.

**What happens during calibration:**

**Step 1: Detect your input source** — Before anything starts, the app checks how audio is coming in. Is it the iPhone's built-in microphone? A USB audio interface plugged into the Lightning or USB-C port? A Bluetooth mic? A wired headset? Each input type has different characteristics, so the app adjusts its processing accordingly (including the bass boost level and noise rejection thresholds described in Part 1).

**Step 2: Measure the silence (3 seconds)** — The app asks you to stay quiet for 3 seconds. During this time, it takes 30 readings of how loud your room is when nobody's playing. It uses the middle value (the median) as your "noise floor" — the baseline level of background sound the app needs to ignore. This tells the system: "anything below this level is just room noise, not guitar."

**Step 3: Play all 6 open strings** — The app walks you through each string one at a time, from low E to high E. For each string, you play the open note and the app tries to detect it. This serves two purposes:
- It confirms the app can actually hear your guitar in your environment
- It captures the auto-gain setting — how much the app needs to amplify (or reduce) your signal to get it to a good working level

**Step 4: Save the profile** — The results are saved: your noise floor measurement, the gain level, which strings were detected successfully, your input source, and a quality score (what fraction of strings were detected). This profile is stored on your phone and loaded every time you start a quiz.

**How the quiz uses your calibration:**

Without calibration, the pitch detector starts "cold" — it doesn't know how loud your room is or how strong your guitar signal will be. It spends the first 5–10 seconds of every quiz adapting, during which it might miss notes or detect them inaccurately.

With calibration, the detector is "pre-seeded" with your measurements before the first note. It already knows your noise floor (so it won't mistake room hum for a note) and your gain level (so it won't under- or over-amplify). The very first note you play gets detected accurately.

**Fine-tuning in Settings:**

After calibration, the Settings screen (under Audio Setup) shows your calibration status and offers two adjustment sliders:
- **Input Gain Trim (±6 dB)** — If the app is still too sensitive or not sensitive enough, you can nudge the gain up or down
- **Noise Gate Trim (±6 dB)** — If the app triggers on background noise or misses quiet playing, you can adjust the noise threshold

These are small tweaks on top of the calibrated values — most people won't need to touch them.

**When to re-calibrate:**

You only need to calibrate once for a given setup. If you move to a different room, switch from the phone mic to a USB interface, or change guitars, you can re-calibrate from the Settings screen or the Practice tab. The new calibration replaces the old one.

---

## Part 3: Adaptive Learning

The learning system in FretShed works like a teacher who keeps detailed notes on every student.

**How it tracks what you know:**

Every position on the fretboard — say, the 3rd fret on the A string (that's a C note) — has its own score. The score isn't just "right or wrong" — it's a probability that represents how confident the app is that you've truly learned that position.

This uses something called Bayesian scoring, which is just a fancy way of saying "update your belief based on new evidence." Every position starts at 50% — the app has no idea if you know it or not. Each time you answer:

- **Get it right** — The score goes up. How much depends on how low the score was before. If you nail a position you've been struggling with, that's a bigger deal than getting an easy one right again.
- **Get it wrong** — The score goes down. Again, the amount depends on context. Missing a position you supposedly "mastered" drops it more than missing one you're still learning.

**The 4-tier mastery system:**

Positions are categorized into four tiers based on their score and attempt count:

- **Struggling** (red) — Score below 50%. You're getting this one wrong more than right.
- **Learning** (amber) — Score between 50–89%. You're improving but not consistent yet.
- **Proficient** (green) — Score 90%+ but fewer than 15 attempts. You're accurate but haven't proven it over enough reps.
- **Mastered** (gold) — Score 90%+ AND 15 or more attempts. You've demonstrated consistent knowledge.

The heatmap uses luminance differences (light to dark) rather than different hues, making tiers easy to distinguish at a glance during practice.

**How it picks what to quiz you on:**

This is where it gets clever. The app doesn't just pick random notes — it uses adaptive weighting to focus on your weak spots.

Think of it like a bag of marbles. Every fretboard position has marbles in the bag, but positions you struggle with have MORE marbles. When the app picks the next question, it reaches into the bag. Positions with low scores (your weak spots) are much more likely to get picked than positions you've already mastered.

Specifically:
- A position you've never tried has a high chance of being selected — the app wants to explore the whole fretboard
- A position you keep getting wrong gets picked frequently — the app wants to drill your weak spots
- A position you've mastered gets picked rarely — just often enough to make sure you still remember it

This means every quiz session automatically becomes personalized. Two people using the app will get completely different sequences of questions based on their individual strengths and weaknesses. The app spends your practice time where it matters most.

**What the Journey tab shows you:**

- **Fretboard heatmap** — A bird's-eye view of the whole fretboard, color-coded by the 4-tier mastery system. You can instantly see clusters of weakness (maybe you're great at the first 5 frets but shaky above the 7th).
- **Cells Attempted** — How many of the total fretboard positions you've tried at least once
- **Cells Mastered** — How many have reached gold tier (90%+ score with 15+ attempts)
- **Overall Mastery** — Your average score across all attempted positions
- **Time Practiced** — Total practice time, responsive to active filters
- **Accuracy Trend** — A chart showing whether you're improving over time
- **Session History** — Every practice session with its score, which you can filter by mode, or use the "Today's Sessions" filter for a quick view of today's work

The filters on the Journey tab also adjust the heatmap and charts — so you can see, for example, "how am I doing on just the low E string?" or "how's my accuracy on timed sessions only?"

**The big picture:**

The system creates a virtuous cycle: practice exposes your weak spots, the app drills those weak spots harder, your weak spots improve, the heatmap fills in, and you gradually build genuine fretboard knowledge — not just memorization of the easy positions you already knew.
