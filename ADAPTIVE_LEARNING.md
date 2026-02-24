# FretShed — How Adaptive Learning Works

The learning system in FretShed works like a teacher who keeps detailed notes on every student:

**How it tracks what you know:**

Every position on the fretboard — say, the 3rd fret on the A string (that's a C note) — has its own score. The score isn't just "right or wrong" — it's a probability that represents how confident the app is that you've truly learned that position.

This uses something called Bayesian scoring, which is just a fancy way of saying "update your belief based on new evidence." Every position starts at 50% — the app has no idea if you know it or not. Each time you answer:

- **Get it right** — The score goes up. How much depends on how low the score was before. If you nail a position you've been struggling with, that's a bigger deal than getting an easy one right again.
- **Get it wrong** — The score goes down. Again, the amount depends on context. Missing a position you supposedly "mastered" drops it more than missing one you're still learning.

A position is considered "mastered" when its score crosses a threshold (which you can adjust in Settings). The fretboard heatmap on the Progress tab shows this visually — cold colors for positions you haven't tried, warming up through yellows and oranges, to green for mastered positions.

**How it picks what to quiz you on:**

This is where it gets clever. The app doesn't just pick random notes — it uses adaptive weighting to focus on your weak spots.

Think of it like a bag of marbles. Every fretboard position has marbles in the bag, but positions you struggle with have MORE marbles. When the app picks the next question, it reaches into the bag. Positions with low scores (your weak spots) are much more likely to get picked than positions you've already mastered.

Specifically:
- A position you've never tried has a high chance of being selected — the app wants to explore the whole fretboard
- A position you keep getting wrong gets picked frequently — the app wants to drill your weak spots
- A position you've mastered gets picked rarely — just often enough to make sure you still remember it

This means every quiz session automatically becomes personalized. Two people using the app will get completely different sequences of questions based on their individual strengths and weaknesses. The app spends your practice time where it matters most.

**What the Progress tab shows you:**

- **Fretboard heatmap** — A bird's-eye view of the whole fretboard, color-coded by mastery. You can instantly see clusters of weakness (maybe you're great at the first 5 frets but shaky above the 7th).
- **Cells Attempted** — How many of the total fretboard positions you've tried at least once
- **Cells Mastered** — How many have crossed the mastery threshold
- **Overall Mastery** — Your average score across all attempted positions
- **Accuracy Trend** — A chart showing whether you're improving over time
- **Session History** — Every practice session with its score, which you can filter by mode (single string, full fretboard, chord progressions, timed sessions, etc.)

The filters on the Progress tab also adjust the heatmap and charts — so you can see, for example, "how am I doing on just the low E string?" or "how's my accuracy on timed sessions only?"

**The big picture:**

The system creates a virtuous cycle: practice exposes your weak spots, the app drills those weak spots harder, your weak spots improve, the heatmap fills in, and you gradually build genuine fretboard knowledge — not just memorization of the easy positions you already knew.
