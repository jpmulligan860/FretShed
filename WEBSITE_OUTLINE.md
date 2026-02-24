# FretShed — Website Outline & Content Guide

> **Purpose:** Marketing site for App Store listing, SEO, and hosting required Apple links (Privacy Policy, Support).
> **Recommended platform:** Carrd.co (free/cheap single-page site) or a simple Next.js/Hugo static site on Vercel.
> **Domain suggestion:** fretshed.com or fretshed.app

---

## Site Structure

Single scrolling page with anchor sections + separate pages for Privacy Policy and Support.

```
fretshed.com/
├── index.html (main marketing page — all sections below)
├── /privacy (Privacy Policy — required by Apple)
└── /support (Support page — required by Apple)
```

---

## Section 1: Hero

**Goal:** Instant clarity on what the app does + download button.

### Content

**Headline:**
> Learn Every Note on the Fretboard

**Subheadline:**
> FretShed is the guitar trainer that actually listens to you play. Real-time pitch detection, adaptive learning, and practice tools — all in one app.

**Call to Action:**
- [Download on the App Store] button (use Apple's official badge)
- "Available for iPhone" subtitle text

**Visual:**
- App icon (large, centered or left-aligned)
- Hero screenshot: Practice tab showing the quiz in action with a detected note on the fretboard

### Screenshot to take
- Quiz screen in portrait with a note detected, showing the fretboard with a green correct answer dot. Use a visually appealing note position (mid-fretboard).

---

## Section 2: The Problem

**Goal:** Connect with the user's frustration. Make them feel understood.

### Content

**Headline:**
> You've been playing for years. Can you name every note on the fretboard?

**Body:**
> Most guitarists learn chord shapes and scale patterns — but never actually learn the individual notes. You know where to put your fingers, but not *why*. When someone says "play a Bb on the G string," you're counting frets from the nut.
>
> FretShed fixes this. In just 10 minutes a day, you'll build genuine fretboard knowledge that transforms how you play, improvise, and communicate with other musicians.

**No screenshot needed** — this is a text-only emotional connection section.

---

## Section 3: How It Works

**Goal:** Show the three-step flow in a simple, scannable format.

### Content

**Headline:**
> How FretShed Works

**Three columns/cards:**

**1. The App Listens**
> Play a note on your guitar. FretShed's pitch detection engine identifies it instantly — no buttons to tap, no cable required. Just your guitar and your phone.

*Icon suggestion: microphone or waveform*

**2. It Adapts to You**
> FretShed tracks your accuracy at every fretboard position. It learns which notes you struggle with and automatically focuses your practice there. No two sessions are the same.

*Icon suggestion: brain or chart trending up*

**3. You Build Mastery**
> Watch your fretboard heatmap fill in from cold to green as you master each position. Track your progress with detailed stats, accuracy trends, and session history.

*Icon suggestion: checkmark or trophy*

### Screenshots to take
- Tuner screen showing a detected note (demonstrates "listens")
- Fretboard heatmap on Progress tab with a mix of colors (demonstrates "adapts")
- Progress tab showing mastery rings and accuracy trend chart (demonstrates "mastery")

---

## Section 4: Features

**Goal:** Comprehensive feature showcase. This is the meat of the page.

### Content

**Headline:**
> Everything You Need to Master the Fretboard

**Feature blocks (alternate image left/right for visual rhythm):**

---

**Real-Time Pitch Detection**
> FretShed hears what you play through your iPhone's microphone — no accessories needed. Advanced signal processing handles acoustic guitars, electrics through USB interfaces, and even distorted tones through pedals. The detection engine adapts to your room's background noise automatically.

*Screenshot: Quiz screen with "Correct!" feedback banner showing*

---

**7 Practice Modes**
> - **Single Note** — Drill one note across the entire fretboard
> - **Single String** — Master every note on one string at a time
> - **Full Fretboard** — Random notes across all strings and frets
> - **Chord Progressions** — Identify chord tones (roots, 3rds, 5ths) across the neck
> - **Timed Mode** — Race the clock to sharpen your response time
> - **Streak Mode** — How many can you get right in a row?
> - **Tap to Answer** — Tap directly on the fretboard to identify notes visually

*Screenshot: Practice tab showing the session setup screen with mode options*

---

**Adaptive Learning**
> Every fretboard position has its own mastery score. FretShed's Bayesian scoring algorithm learns your weak spots and drills them more often. Positions you've mastered appear less frequently — your practice time goes exactly where it's needed most.

*Screenshot: Fretboard heatmap (Progress tab) showing a mix of mastery levels — some green, some yellow, some untried*

---

**Detailed Progress Tracking**
> See your improvement over time with accuracy trend charts, response time tracking, and a full session history. Filter by practice mode, string, or session type. The fretboard heatmap gives you a bird's-eye view of your knowledge at a glance.

*Screenshot: Progress tab showing the accuracy trend chart and overall stats*

---

**Built-In Tuner**
> A precise chromatic tuner powered by the same detection engine as the quiz. Tune up before you practice — no need to switch apps.

*Screenshot: Tuner tab showing a note in tune (needle centered, green)*

---

**Metronome, Speed Trainer & Drones**
> A full-featured metronome with note divisions (quarter, eighth, triplet, sixteenth), beat accents, and a speed trainer that gradually increases tempo. Three drone sounds (Pure, Rich, Piano) in any key with Root, Power Chord, Major, and Minor voicings. The drone's LFO syncs with the metronome beat for a musical practice backdrop.

*Screenshot: MetroDrone tab showing the metronome controls and drone settings*

---

**Audio Calibration**
> A one-time calibration measures your room's noise level and your guitar's signal strength, then pre-loads those settings every time you practice. First-note accuracy from the moment you start.

*Screenshot: Calibration screen showing the string test step with checkmarks*

---

## Section 5: Who It's For

**Goal:** Help visitors self-identify. Broaden appeal beyond beginners.

### Content

**Headline:**
> Built for Every Guitarist

**Three audience cards:**

**Beginners**
> Just starting out? FretShed gives you a structured way to learn the fretboard from day one. The adaptive system meets you where you are and grows with you.

**Intermediate Players**
> You know your open chords and some barre shapes, but the notes above the 5th fret are a mystery. FretShed fills in those gaps fast.

**Advanced Players**
> You can improvise and read charts, but instant note recall across the entire neck would make you faster and more confident. FretShed's timed mode and streak challenges push your speed.

**No screenshot needed** — use icons or simple illustrations.

---

## Section 6: Testimonials / Social Proof

**Goal:** Build trust. Leave this section as a placeholder until you have beta tester feedback.

### Content

**Headline:**
> What Guitarists Are Saying

*Placeholder: 3 quote blocks. Fill in after TestFlight beta (Phase 5).*

> "Quote from beta tester about how quickly they saw improvement."
> — Name, playing experience

---

## Section 7: Pricing

**Goal:** Clear, simple pricing. No surprises.

### Content

**Headline:**
> Start Free. Go Premium When You're Ready.

**Two columns:**

| Free | Premium |
|------|---------|
| Single Note mode | All 7 practice modes |
| Strings 4–6, Frets 0–7 | Full fretboard access |
| Tap input | Real-time audio detection |
| 7-day session history | Unlimited history |
| Built-in tuner | Tuner + Metronome + Drones |
| | Audio calibration |
| | Chord progressions |
| **Free forever** | **$4.99/mo or $29.99/yr** |
| | 7-day free trial |

**CTA button:** [Start Your Free Trial]

*Note: Adjust this table once you finalize the free/premium gates in Phase 4.*

---

## Section 8: Download CTA (Bottom)

**Goal:** Final conversion point. Repeat the App Store button.

### Content

**Headline:**
> Ready to Actually Learn the Fretboard?

**Subheadline:**
> Download FretShed and start your first session in under 2 minutes.

**CTA:** [Download on the App Store] badge

**Below the badge:**
> Requires iPhone with iOS 17 or later. No account required. No internet required. Your data stays on your device.

---

## Separate Page: Privacy Policy (/privacy)

**Required by Apple for App Store submission.**

### Key points to include
- FretShed uses the microphone solely for real-time pitch detection
- No audio is recorded, stored, or transmitted
- All data (session history, progress, settings) is stored locally on the device using SwiftData
- No user accounts, no cloud sync, no third-party analytics
- No data is collected or shared with third parties
- Contact email for privacy questions

*Recommendation: Use termly.io (free) to generate a compliant privacy policy, then customize it.*

---

## Separate Page: Support (/support)

**Required by Apple for App Store submission.**

### Content

**Headline:**
> FretShed Support

**FAQ format:**

**The app can't hear my guitar.**
> Make sure you've granted microphone permission (Settings > FretShed > Microphone). Run the Audio Calibration from the Practice tab. Play in a quiet room and hold the phone 12–18 inches from your guitar.

**The detected note is wrong.**
> Run Audio Calibration if you haven't already. Make sure you're playing one note at a time (mute adjacent strings). If using an electric guitar, try a clean tone — heavy distortion can affect detection accuracy.

**How do I use FretShed with a USB audio interface?**
> Plug your interface into your iPhone's Lightning or USB-C port. FretShed will automatically detect the external input and adjust its processing. Run Audio Calibration after switching input sources.

**Can I use FretShed without a microphone?**
> Yes. Enable "Tap Testing Mode" in Settings to answer with on-screen buttons, or use "Tap to Answer" to tap directly on the fretboard. These modes work without microphone access.

**How do I reset my progress?**
> Go to Settings > Data Management > Delete All Sessions.

**Contact:**
> For questions, feedback, or bug reports, email **support@fretshed.com** (or your preferred email address).

---

## Screenshot Checklist

Take all screenshots on **iPhone 16 Pro Max** simulator (6.9" display) for App Store + website use.

| # | Screen | What to show | Notes |
|---|--------|-------------|-------|
| 1 | Quiz (portrait) | Active question with correct answer green dot | Use a mid-fretboard position for visual appeal |
| 2 | Quiz (portrait) | "Correct!" feedback banner | Capture during the 1.5s feedback window |
| 3 | Practice tab | Full tab with Do This First card + Quick Start cards | Shows the app's home screen |
| 4 | Session setup | Mode picker, string/fret options visible | Shows the depth of customization |
| 5 | Progress tab | Heatmap with mixed colors + overall stats | Needs some session data — play 10-15 sessions first |
| 6 | Progress tab | Accuracy trend chart | Scroll down to show the chart |
| 7 | Tuner | Note detected, needle centered, green color | Tune a string to get a perfect green reading |
| 8 | MetroDrone | Metronome controls + drone settings visible | Show both sections |
| 9 | Calibration | String test screen with some checkmarks | Mid-calibration, 3-4 strings done |
| 10 | Session results | Completed session with score and stats | After finishing a session |

**Pro tips:**
- Use **Cmd+S** in Simulator to save screenshots to Desktop
- Put the phone in a real-looking context using mockup tools (Rotato, Previewed, or free Figma templates)
- For the website hero, consider a 3-phone mockup showing Practice + Quiz + Progress side by side
- Add 1-line benefit text overlays to App Store screenshots using Canva

---

## SEO & Metadata

```html
<title>FretShed — Learn Every Note on the Guitar Fretboard</title>
<meta name="description" content="FretShed is the guitar fretboard trainer that listens to you play. Real-time pitch detection, adaptive learning, built-in tuner, metronome, and drones. Free for iPhone.">
<meta name="keywords" content="guitar fretboard trainer, learn guitar notes, fretboard memorization, guitar note quiz, pitch detection guitar app, guitar tuner, guitar practice app, learn fretboard notes, guitar ear training">
```

**Open Graph (for social sharing):**
```html
<meta property="og:title" content="FretShed — Learn Every Note on the Guitar Fretboard">
<meta property="og:description" content="The guitar trainer that actually listens to you play. Master the fretboard with adaptive learning and real-time pitch detection.">
<meta property="og:image" content="[URL to hero image or app icon]">
<meta property="og:url" content="https://fretshed.com">
```
