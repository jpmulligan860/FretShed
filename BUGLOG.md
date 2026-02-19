# FretMaster — Bug Log

Log issues found during physical device testing. For each bug, note what you tapped, what you expected, and what actually happened. Include iOS version and device if relevant.

**Status key**: 🐛 Open · 🔧 In Progress · ✅ Fixed

---

## Practice Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## Progress Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## Tuner Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## MetroDrone Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## Settings Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## Quiz / Fretboard (launched from Practice)

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| — | — | No bugs logged yet | — | — |

---

## Known Anomalies (from file audit — not yet investigated)

| # | Status | Description | Location | Notes |
|---|---|---|---|---|
| A1 | 🐛 Open | 5 stray Swift files inside `FretMaster.xcodeproj/` | `FretMaster.xcodeproj/CellDetailSheet.swift`, `MasteryHeatmapView.swift`, `ProgressView.swift`, `ProgressViewModel.swift`, `ProgressViewModelTests.swift` | Likely dragged there accidentally in Xcode. Investigate and move or delete. |
| A2 | 🐛 Open | 2 loose Swift files in project root | `./NotificationScheduler.swift`, `./Repositories.swift` | Not inside any folder group. Need to confirm if they're referenced by the project or are dead code. |
| A3 | 🐛 Open | `Progress/Repositories.swift` is a third copy of the repository protocols | `FretMaster/Progress/Repositories.swift` | Already have copies in `Data/SwiftData/` and `Domain/Repositories/`. One source of truth needed. |

---

## Fixed Bugs

| # | Description | Fixed In | Commit |
|---|---|---|---|
| — | — | — | — |
