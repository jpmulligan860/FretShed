# FretShed — Device Test Guide
**Build date:** 2026-02-22
**Device:** iPhone 16 Pro, iOS 26.2.1
**Prerequisites:** Install the latest build via Xcode. Use an acoustic or semi-hollow guitar in a quiet room. Have your guitar tuned to standard tuning (EADGBE) before you start.

---

## How to use this guide

Work through each section in order. Each fix has:
- **What was broken** — the original symptom
- **What to test** — step-by-step instructions
- **Pass criteria** — what "fixed" looks like

Mark each item ✅ Pass or ❌ Fail with any notes.

---

## 1 — Launch & Layout (L1)

**What was broken:** Black bars at the top and bottom of every tab (letterboxed display).

**Test steps:**
1. Launch the app fresh from the home screen.
2. Look at all five tabs — Practice, Progress, Tuner, MetroDrone, Settings.

**Pass:** Content fills edge-to-edge on all tabs. No black bars above the tab bar or below the status bar.

---

## 2 — Settings: Persistence (S1)

**What was broken:** Any change made in Settings was lost after closing and relaunching the app.

**Test steps:**
1. Go to **Settings**.
2. Change **Default Focus Mode** to something other than the current value (e.g. "Streak").
3. Change **Session Length** to 10 questions.
4. Change **Note Highlighting** to "Reveal After".
5. Force-quit the app (swipe up from app switcher).
6. Relaunch the app.
7. Go back to **Settings**.

**Pass:** All three values you changed are still showing the new values after relaunch.

---

## 3 — Settings: Fret Count Options (S2)

**What was broken:** The Default Fret Count picker showed wrong choices.

**Test steps:**
1. Go to **Settings > Display**.
2. Tap **Default Fret Count**.

**Pass:** The available choices are exactly: **12, 21, 22, 24**.

---

## 4 — Settings: Response Sound Controls (S3, S4)

**What was broken:** There were separate toggles and volume sliders for correct and incorrect sounds.

**Test steps:**
1. Go to **Settings > Audio**.
2. Look at the sound controls.

**Pass:** There is exactly **one toggle** labelled "Response Sounds" and exactly **one volume slider** labelled "Response Sound Volume". No separate correct/incorrect controls.

---

## 5 — Settings: Session Length (S9)

**What was broken:** The Session Length slider had no effect — quizzes always ran for 20 questions regardless.

**Test steps:**
1. Go to **Settings > Quiz Defaults**.
2. Set **Session Length** to **10 questions**.
3. Go to **Practice**, choose any mode, and start a session.
4. Count the questions as you answer them (use Tap Mode if needed — see Section 9).

**Pass:** The quiz ends after exactly 10 questions and shows results.

**Repeat:** Set Session Length to **15**, run another session, confirm it ends at 15.

---

## 6 — Settings: Timer Duration Range (S6)

**What was broken:** The Timer Duration slider had an incorrect range.

**Test steps:**
1. Go to **Settings > Quiz Defaults**.
2. Look at the **Timer Duration** slider.

**Pass:** The slider moves between **2 seconds** and **20 seconds**.

---

## 7 — Settings: Hint Timeout (S7)

**What was broken:** Setting a Hint Timeout had no effect — the hint only appeared if you tapped "Show Hint" manually.

**Test steps:**
1. Go to **Settings > Quiz Defaults**.
2. Set **Hint Timeout** to **3 seconds**.
3. Start any practice session.
4. When a question appears, do NOT tap "Show Hint". Just wait.

**Pass:** After approximately 3 seconds the fret number hint appears automatically without you tapping anything.

**Also test:** Tap "Show Hint" immediately on a different question — the hint should still appear instantly on demand.

---

## 8 — Settings: Mastery Threshold Label (S8)

**What was broken:** The mastery threshold was labelled confusingly.

**Test steps:**
1. Go to **Settings > Quiz Defaults**.
2. Find the mastery threshold control.

**Pass:** It is labelled **"Set Mastery Threshold"**.

---

## 9 — Settings: Tap Mode (P5)

**What was broken:** There was no way to enable Tap Mode (self-assessment without microphone).

**Test steps:**
1. Go to **Settings > Audio**.
2. Find and enable the **Tap Mode** toggle.
3. Go to **Practice** and start any session.

**Pass:** Instead of the microphone listening view, you see a **Correct** button and a **Wrong** button. The mic is not active. Tapping Correct or Wrong moves to the next question and scores accordingly.

4. Return to **Settings > Audio** and turn Tap Mode **off**.
5. Start a session again.

**Pass:** The microphone listening view returns.

---

## 10 — Note Highlighting: Reveal After (S5)

**What was broken:** When "Reveal After" was selected, the target note dot was visible before you played anything.

**Test steps:**
1. Go to **Settings > Quiz Defaults > Note Highlighting** and select **Reveal After**.
2. Start any practice session.
3. When the first question appears, look at the fretboard immediately — before playing anything.

**Pass:** The fretboard shows **no orange dot** — the target position is hidden.

4. Play the correct note (or use Tap Mode and tap Correct).

**Pass:** The orange dot appears at the target fret position after your answer.

5. Now intentionally play a **wrong** note (or tap Wrong in Tap Mode).

**Pass:** The orange dot still appears after the wrong answer, showing you where the correct note was.

---

## 11 — Quiz: Correct Note Messages (Q3)

**What was broken:** After a correct answer, all encouragement messages cycled through rapidly in sequence instead of showing one random message.

**Test steps:**
1. Start a practice session with Tap Mode on.
2. Answer several questions correctly in a row by tapping Correct.
3. Watch the message that appears in the feedback area after each correct answer.

**Pass:** Each correct answer shows **one** encouragement message that stays stable. Different questions may show different messages, but each message does not rapidly cycle through multiple phrases.

---

## 12 — Quiz: Fretboard Sizing (Q1)

**What was broken:** At 22 or 24 fret count, the note dots overlapped each other and fret wires.

**Test steps:**
1. Go to **Settings > Display > Default Fret Count** and set it to **24**.
2. Start a practice session in Full Fretboard mode.
3. Look at the fretboard displayed in the quiz.

**Pass:** All 24 frets are visible across the width of the screen. The note dots are smaller than at 12 frets but do **not** overlap each other or the fret wires. The fretboard does not scroll.

4. Change Default Fret Count back to **12** and run another session.

**Pass:** At 12 frets the dots are noticeably larger — the dot size adapts proportionally.

---

## 13 — Quiz: Correct Note Revealed After Wrong Answer (Q5)

**What was broken:** After an incorrect answer, the fretboard showed no dot — the user had no way to see where the correct note was.

**Test steps:**
1. In **Settings > Quiz Defaults**, set **Note Highlighting** to **Single Position**.
2. Start a session with **Tap Mode on** (so you can control right/wrong deliberately).
3. When a question appears, tap **Wrong**.

**Pass:** The orange dot appears on the fretboard at the correct fret position immediately after tapping Wrong.

4. Change **Note Highlighting** to **Reveal After** and repeat the test.

**Pass:** The orange dot also appears after tapping Wrong in Reveal After mode (it was hidden before you answered, but reveals on both correct and incorrect).

5. Change **Note Highlighting** to **All Positions** and repeat.

**Pass:** After tapping Wrong, all occurrences of the target note across every string light up in green, plus the orange target dot.

---

## 14 — Audio Detection: Overall Accuracy (P1, P3)

**What was broken:** Note detection was unreliable because the microphone signal from an acoustic guitar was too quiet for the algorithm. Too many false incorrect results.

**Test steps:**
1. Make sure Tap Mode is **off**.
2. Go to **Settings > Audio** and confirm Detection Confidence is at its default (~85%).
3. Start a **Single String** session on string 6 (low E).
4. Play each note clearly, one at a time, allowing the string to ring for at least one second. Use a moderate picking attack — not a whisper but not aggressive.

**Pass:** The majority of clearly-played notes are detected correctly on the first attempt. Expect occasional misses — aim for >80% accuracy on sustained notes.

5. Repeat on **string 1 (high e)** at various frets.

**Pass:** High-string detection is similarly reliable.

---

## 15 — Audio Detection: Low String Octave Errors (P2)

**What was broken:** The C# and A notes on the 6th string (and other low string notes) were frequently detected as the wrong note, often one octave too high.

**Test steps:**
1. Start a **Single String** session on string 6 with **Tap Mode off**.
2. Play open E (open string 6), A (fret 5), and C# (fret 9) slowly and clearly.

**Pass:** Each note is identified correctly. Open E is not detected as E one octave higher. A is not detected as A5. Play each note 3–4 times — the majority should be correct.

3. Repeat with the **A string (string 5)** on open A (open) and D (fret 5).

**Pass:** Similarly correct without octave jumping.

---

## 16 — Audio Detection: Staccato Notes (P1, P3, P4)

**What was broken:** Short, staccato notes were frequently missed or marked wrong.

**Test steps:**
1. Start any practice session with Tap Mode off.
2. Pick notes staccato — a short, clean pluck with your right hand muting the string immediately after.

**Pass:** Staccato notes played with a clear attack register correctly. You may need a slightly firmer pick attack for staccato vs sustained — that is acceptable. Aim for >70% accuracy on staccato.

---

## 17 — Tuner: Hollow Body / Quiet Guitar (T1)

**What was broken:** The tuner needle jumped erratically when tuning a hollow or semi-hollow guitar with the internal mic.

**Test steps:**
1. Go to the **Tuner** tab.
2. Use a hollow or semi-hollow guitar (or any acoustic guitar) in a quiet room.
3. Play any open string and watch the tuner needle.

**Pass:** The needle moves to the pitch area of the string you played and settles relatively stably. Some movement is normal and expected — the needle should not jump wildly between distant pitch values on every pluck.

---

## 18 — Tuner: Needle Stability as Note Decays (T2, T3)

**What was broken:** As a note's volume decayed, the needle either (a) drifted away from the correct pitch, or (b) snapped back to the center before the note had fully died.

**Test steps:**
1. Go to the **Tuner** tab.
2. Play any open string with a clear, sustained pluck.
3. Watch the needle carefully as the note rings and then fades.

**Pass (T2):** The needle does **not** drift away from the correct pitch as the note gets quieter. It should hold position.

**Pass (T3):** The needle holds its position for approximately **0.25 seconds** after the note becomes inaudible, then returns to center. It should **not** snap instantly back to center the moment the note starts to fade.

4. Repeat with a few different strings and frets.

**Pass:** Consistent hold-then-release behaviour across all strings.

---

## 19 — Progress Tab: Heatmap Sizing (Pr1, Pr2)

**What was broken:** The fretboard heatmap in the Progress tab and session results was horizontally scrollable instead of auto-sizing to fit the screen.

**Test steps (Progress tab):**
1. Complete at least one practice session so there is data.
2. Go to the **Progress** tab.
3. Look at the fretboard heatmap.

**Pass:** The entire heatmap — all strings and all frets up to your Default Fret Count — is visible without scrolling. The heatmap fits within the screen width.

**Test steps (Session results):**
1. Complete a practice session.
2. When the session results screen appears, look at the heatmap.

**Pass:** Same as above — full fretboard visible without horizontal scrolling.

**Additional check:** Go to **Settings > Default Fret Count**, change to **24**, then run a session and check both heatmaps again. All 24 frets should still fit without scrolling (cells will be smaller).

---

## 20 — MetroDrone: Drone Play Button Placement (M1)

**What was broken:** The Drone play button was in the wrong section of the MetroDrone tab.

**Test steps:**
1. Go to the **MetroDrone** tab.
2. Find the Drone section.

**Pass:** The play button for the drone is located within the **Drone Settings** section, not outside it or in the Metronome section.

---

## 21 — MetroDrone: Section Labels (M2)

**What was broken:** The accent, mute, and note buttons had no section title, leaving users unsure what they controlled.

**Test steps:**
1. Go to the **MetroDrone** tab.
2. Look at the metronome beat/accent controls.

**Pass:** There is a visible **section title** above the accent, mute, and note buttons.

---

## 22 — MetroDrone: Drone Octave Range (M4)

**What was broken:** The drone octave picker included octave 1 (too low to hear) and octave 5 (annoying/piercing).

**Test steps:**
1. Go to the **MetroDrone** tab.
2. Find the octave picker for the drone.

**Pass:** Octave 1 and octave 5 are **not available**. Only the mid-range octaves (2, 3, 4) are selectable.

---

## 23 — Tuner: Simplified Controls (F6, F7)

**What was broken / changed:** 432 Hz reference tuning and strobe display mode were removed to simplify the tuner.

**Test steps:**
1. Go to the **Tuner** tab.
2. Look for any reference frequency or display mode controls.

**Pass:** There is no 432 Hz option. There is no strobe display option. The tuner uses needle mode at 440 Hz.

---

## 24 — Settings: No Haptic Feedback Toggle (F8)

**What was broken / changed:** A haptic feedback toggle was removed from settings since the phone is typically not held during use.

**Test steps:**
1. Go to **Settings**.
2. Look for a haptic feedback or vibration toggle.

**Pass:** No haptic feedback toggle is present.

---

## 25 — Session Results: Done & View Progress buttons (Q-exit)

**What was broken:** After completing a session, the results screen appeared but tapping Done or View Progress had no effect — the screen was stuck.

**Test steps:**
1. Start any practice session (Tap Mode on is fine).
2. Answer all questions until the session completes and the results screen appears.
3. Tap **Done**.

**Pass:** The results screen dismisses and you return to the Practice tab home screen.

4. Run another session to completion.
5. Tap **View Progress**.

**Pass:** The results screen dismisses AND the app switches to the **Progress** tab.

---

## 26 — Quiz Results: Repeat Button (F1)

**What was added:** A "Repeat" button on the session results screen that immediately re-starts an identical session.

**Test steps:**
1. Enable **Tap Mode** in Settings > Audio (makes it easy to complete sessions quickly).
2. Go to **Practice**, start any session, and answer all questions.
3. When the session results screen appears, look at the buttons.

**Pass:** Three buttons are visible — **Done**, **View Progress**, and **Repeat** (or similar layout).

4. Tap **Repeat**.

**Pass:** The results screen dismisses and a new quiz starts immediately with the same focus mode, notes, strings, and other settings as the session you just completed. You are not taken to the setup screen.

5. Complete the repeated session. When results appear, tap **Done**.

**Pass:** Results dismiss cleanly and you return to the Practice tab.

---

## 27 — Progress Tab: Filter by Session Type (F3)

**What was added:** A filter menu on the Progress tab's Recent Sessions section to show only sessions of a chosen type.

**Test steps:**
1. Complete at least **3 sessions** using different modes — e.g. one Single Note, one Single String, one Full Fretboard.
2. Go to the **Progress** tab and scroll to the **Recent Sessions** list.
3. Look for a filter icon near the "RECENT SESSIONS" header.

**Pass:** A filter button (funnel icon) is visible next to the section header.

4. Tap the filter button and select **Single Note**.

**Pass:** The session list updates to show only Single Note sessions. Sessions from other modes disappear from the list.

5. Tap the filter button again and select **All Sessions**.

**Pass:** All sessions are shown again.

6. Tap the filter button and select a mode for which you have **no sessions** (if any exists).

**Pass:** An empty state message appears instead of an empty list, indicating no sessions for that filter.

---

## 28 — MetroDrone: Note Division (F4)

**What was added:** A Note Division segmented picker that adds sub-beat clicks between main beats (1/8, Triplet, 1/16).

**Test steps:**
1. Go to the **MetroDrone** tab.
2. Find the **Note Division** control in the metronome settings section.

**Pass:** A segmented picker with four options is visible: **1/4**, **1/8**, **Triplet**, **1/16**.

3. Set BPM to a slow tempo (e.g. 60) so sub-beats are easy to hear.
4. Set Note Division to **1/4** and tap **Start Metronome**.

**Pass:** You hear one click per beat — 60 clicks per minute. No sub-clicks between beats.

5. Change Note Division to **1/8** while the metronome is running (or stop, change, restart).

**Pass:** You hear two clicks per beat — one louder main beat click and one quieter sub-beat click between each main beat.

6. Change Note Division to **Triplet**.

**Pass:** You hear three clicks per beat — main beat plus two quieter sub-beat clicks, evenly spaced.

7. Change Note Division to **1/16**.

**Pass:** You hear four clicks per beat — main beat plus three quieter sub-beat clicks.

8. Stop the metronome and change to a different time signature (e.g. 3/4), then restart with **1/8**.

**Pass:** Sub-beats work correctly in the new time signature too.

---

## 29 — Quiz Results: Buttons Tappable on Short Sessions (Q6)

**What was broken:** When Session Length was set to 5 questions, the results screen appeared but tapping Done, View Progress, or Repeat had no effect.

**Test steps:**
1. Go to **Settings > Quiz Defaults** and set **Session Length** to **5**.
2. Enable **Tap Mode** in Settings > Audio.
3. Start a practice session and answer all 5 questions.
4. When the results screen appears, tap **Done**.

**Pass:** The results screen dismisses cleanly and you return to the Practice tab. No stuck/frozen screen.

5. Run another 5-question session to completion.
6. Tap **View Progress**.

**Pass:** Results dismiss and the app switches to the Progress tab.

7. Run a third 5-question session to completion.
8. Tap **Repeat**.

**Pass:** Results dismiss and a new 5-question session starts immediately.

**Also test at other short lengths:** Repeat step 1–4 with Session Length set to **3** and then **8**.

**Pass:** Buttons work at all short session lengths.

---

## Summary Checklist

| # | Fix | Area | Result |
|---|-----|------|--------|
| 1 | L1 — No black bars on launch | All tabs | |
| 2 | S1 — Settings persist after relaunch | Settings | |
| 3 | S2 — Fret count options: 12, 21, 22, 24 | Settings | |
| 4 | S3/S4 — Single response sound toggle + slider | Settings | |
| 5 | S9 — Session length slider works | Settings → Quiz | |
| 6 | S6 — Timer range 2–20 seconds | Settings | |
| 7 | S7 — Hint appears automatically after timeout | Settings → Quiz | |
| 8 | S8 — "Set Mastery Threshold" label | Settings | |
| 9 | P5 — Tap Mode works | Settings → Quiz | |
| 10 | S5 — Reveal After hides dot until answer | Settings → Quiz | |
| 11 | Q3 — One encouragement message per correct answer | Quiz | |
| 12 | Q1 — Fretboard dots scale at 22/24 frets | Quiz | |
| 13 | Q5 — Correct note shown after wrong answer | Quiz | |
| 14 | P1/P3 — Improved detection accuracy | Practice | |
| 15 | P2 — No octave errors on low strings | Practice | |
| 16 | P1/P3/P4 — Staccato notes detected | Practice | |
| 17 | T1 — Tuner works on hollow/acoustic guitar | Tuner | |
| 18 | T2/T3 — Needle holds position as note decays | Tuner | |
| 19 | Pr1/Pr2 — Heatmap fits screen without scrolling | Progress | |
| 20 | M1 — Drone play button in correct section | MetroDrone | |
| 21 | M2 — Section title on beat controls | MetroDrone | |
| 22 | M4 — Drone octave range correct | MetroDrone | |
| 23 | F6/F7 — No 432 Hz / no strobe mode | Tuner | |
| 24 | F8 — No haptic feedback toggle | Settings | |
| 25 | Q-exit — Done / View Progress buttons work | Quiz results | |
| 26 | F1 — Repeat button on session results | Quiz results | |
| 27 | F3 — Progress filter by session type | Progress | |
| 28 | F4 — Note Division sub-beat clicks | MetroDrone | |
| 29 | Q6 — Buttons tappable on 5-question sessions | Quiz results | |

---

*Generated 2026-02-22. File any failures back in BUGLOG.md with device, iOS version, and steps to reproduce.*
