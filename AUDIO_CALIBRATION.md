# FretShed — How Audio Calibration Works

**Why calibrate at all?**

Every room sounds different — a bedroom is quieter than a living room with a TV on. Every guitar sounds different — a nylon classical guitar is much quieter than a steel-string acoustic. And every phone picks up sound slightly differently depending on its case, angle, and distance from the guitar. Calibration measures your specific setup once so the app doesn't have to guess.

**What happens during calibration:**

**Step 1: Detect your input source** — Before anything starts, the app checks how audio is coming in. Is it the iPhone's built-in microphone? A USB audio interface plugged into the Lightning or USB-C port? A Bluetooth mic? A wired headset? Each input type has different characteristics, so the app adjusts its processing accordingly.

**Step 2: Measure the silence (3 seconds)** — The app asks you to stay quiet for 3 seconds. During this time, it takes 30 readings of how loud your room is when nobody's playing. It uses the middle value (the median) as your "noise floor" — the baseline level of background sound the app needs to ignore. This tells the system: "anything below this level is just room noise, not guitar."

**Step 3: Play all 6 open strings** — The app walks you through each string one at a time, from low E to high E. For each string, you play the open note and the app tries to detect it. This serves two purposes:
- It confirms the app can actually hear your guitar in your environment
- It captures the auto-gain setting — how much the app needs to amplify (or reduce) your signal to get it to a good working level

**Step 4: Save the profile** — The results are saved: your noise floor measurement, the gain level, which strings were detected successfully, your input source, and a quality score (what fraction of strings were detected). This profile is stored on your phone and loaded every time you start a quiz.

**How the quiz uses your calibration:**

Without calibration, the pitch detector starts "cold" — it doesn't know how loud your room is or how strong your guitar signal will be. It spends the first 5–10 seconds of every quiz adapting, during which it might miss notes or detect them inaccurately.

With calibration, the detector is "pre-seeded" with your measurements before the first note. It already knows your noise floor (so it won't mistake room hum for a note) and your gain level (so it won't under- or over-amplify). The very first note you play gets detected accurately.

**Fine-tuning in Settings:**

After calibration, the Settings screen shows your calibration status and offers two adjustment sliders:
- **Input Gain Trim (±6 dB)** — If the app is still too sensitive or not sensitive enough, you can nudge the gain up or down
- **Noise Gate Trim (±6 dB)** — If the app triggers on background noise or misses quiet playing, you can adjust the noise threshold

These are small tweaks on top of the calibrated values — most people won't need to touch them.

**When to re-calibrate:**

You only need to calibrate once for a given setup. If you move to a different room, switch from the phone mic to a USB interface, or change guitars, you can re-calibrate from the Settings screen or the Practice tab. The new calibration replaces the old one.
