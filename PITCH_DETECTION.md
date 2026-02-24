# FretShed — How Pitch Detection Works

Here's how FretShed figures out what note you're playing:

**1. Listening** — The iPhone mic captures raw audio 44,100 times per second. Every ~23 milliseconds, a chunk of audio arrives for analysis.

**2. Filtering out rumble** — A high-pass filter removes everything below 60 Hz (room vibrations, air conditioning hum, handling noise). Guitar's lowest note (low E) is 82 Hz, so nothing useful is lost.

**3. Is anyone playing?** — A noise gate checks if the sound is loud enough to be a guitar note vs. background silence. If it's too quiet, the system waits.

**4. Volume leveling** — Auto-gain control adjusts the signal to a consistent loudness. Whether you're playing softly or strumming hard, the analysis sees a normalized signal. This also adapts to different mic distances and guitar volumes.

**5. Boosting bass strings** — iPhone mics are physically tiny and naturally weak at low frequencies. A bass boost compensates for this, making wound strings (E, A, D) register as strongly as treble strings.

**6. Removing background noise** — During silent moments, the system learns what your room's background noise "looks like" (frequency by frequency). When you play, it subtracts that noise fingerprint from the signal, like noise cancellation headphones but for pitch detection.

**7. Is this a musical note or just noise?** — Three checks run in parallel:
   - **Spectral flatness** — A guitar note has energy concentrated at specific frequencies (harmonics). Random noise has energy spread evenly everywhere. If the energy is too evenly spread, it's rejected as noise (like string slides or pick scrapes).
   - **Crest factor** — Measures how "peaky" vs. "squashed" the signal is. A distorted guitar signal through a pedal looks squashed (clipped), which would normally look like noise. This check recognizes distortion as intentional and lets it through.
   - **Harmonic regularity** — Checks if energy peaks are evenly spaced (at 1x, 2x, 3x, 4x the fundamental frequency). Real notes — clean or distorted — always have this pattern. Noise doesn't.

**8. Finding the pitch (YIN algorithm)** — This is the core. The algorithm asks: "If I shift this waveform forward in time, at what delay does it look most like itself?" That delay corresponds to the fundamental frequency. A sound wave at 110 Hz (A string) repeats every 1/110th of a second, so the algorithm finds a strong self-similarity at that delay. This is done using the Accelerate framework (Apple's optimized math library) for speed.

**9. Octave verification (HPS)** — The YIN algorithm sometimes picks up the 2nd harmonic instead of the fundamental (hearing A4 instead of A3). A second algorithm called Harmonic Product Spectrum cross-checks by multiplying the frequency spectrum with compressed copies of itself — the true fundamental "wins" because all harmonics line up there. If YIN and HPS disagree by an octave, the system corrects down.

**10. Confidence check** — YIN produces a confidence score (0–1). If the algorithm isn't confident enough in its answer, the result is discarded rather than showing a wrong note.

**11. Smoothing** — A median filter removes one-off glitches (like a single weird frame in the middle of a held note).

**12. String-aware filtering (quiz only)** — During a quiz, the system knows which string you should be playing on. It only accepts frequencies within that string's range (±1 semitone tolerance), rejecting sympathetic vibrations from other strings.

**13. Consecutive frame check** — The same note must be detected 3 frames in a row (~70ms) before it's shown. This prevents momentary blips from registering as answers.

**14. Display** — The confirmed note name appears on screen (or is scored correct/incorrect in quiz mode).

The whole chain from mic input to note display takes roughly 70–100ms — fast enough to feel instantaneous while playing.
