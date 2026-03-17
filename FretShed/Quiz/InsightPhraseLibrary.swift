// InsightPhraseLibrary.swift
// FretShed — Quiz Layer
//
// Static phrase pools for SessionInsightEngine insight cards.
// All phrases follow the tone rules: forward-frame weaknesses,
// anchor to delta, never use "bad"/"failed"/"wrong"/"poor"/"struggling".

import Foundation

enum InsightPhraseLibrary {

    // MARK: - Phrase Selection

    /// Deterministic cycling: sessionCount % pool.count
    static func phrase(from pool: [String], sessionCount: Int) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[sessionCount % pool.count]
    }

    // MARK: - weakString (forward-framing required)

    static let weakStringPhrases: [String] = [
        "Your [STRING] string is your current focus. FretShed is drilling it harder.",
        "[STRING] string frets [RANGE]: that's where your next gains are.",
        "[STRING] string is [ACCURACY]% right now. That's exactly where today's session went.",
        "FretShed has its eye on your [STRING] string. You'll see more of those notes.",
    ]

    // MARK: - strongString

    static let strongStringPhrases: [String] = [
        "Your [STRING] string is looking solid at [ACCURACY]%.",
        "[STRING] string is your strongest right now — [ACCURACY]%.",
        "The [STRING] string led the way this session. Nice work.",
        "[STRING] string at [ACCURACY]% — that's your best string right now.",
    ]

    // MARK: - hardestNote

    static let hardestNotePhrases: [String] = [
        "[NOTE] is your trickiest note right now. FretShed is on it.",
        "[NOTE] across the neck — that's the note FretShed is targeting most.",
        "The note [NOTE] keeps showing up in your drill. It'll click.",
        "[NOTE] is getting the most attention from FretShed right now.",
    ]

    // MARK: - tierTransition

    static let tierTransitionPhrases: [String] = [
        "[NOTE] on the [STRING] string just moved to [TIER]. That's real progress.",
        "[COUNT] notes levelled up this session. The heatmap is shifting.",
        "[NOTE] is now [TIER]. Took [ATTEMPTS] reps — worth every one.",
        "Breakthrough: [NOTE] crossed into [TIER]. FretShed saw it happen.",
    ]

    // MARK: - consistencyTrend (positive)

    static let consistencyTrendPositivePhrases: [String] = [
        "Your accuracy has been climbing over the last few sessions.",
        "Three sessions in a row with improvement. The reps are working.",
        "Steady progress across your last few sessions. Keep it going.",
        "The trend is clear — you're getting sharper each session.",
    ]

    // MARK: - consistencyTrend (negative/flat)

    static let consistencyTrendFlatPhrases: [String] = [
        "Your accuracy has plateaued — that's normal before a breakthrough.",
        "Flat accuracy across recent sessions. FretShed is adjusting the drill.",
        "Plateaus happen. FretShed is shifting targets to push through.",
        "Steady but flat — the next session could be the one that breaks through.",
    ]

    // MARK: - closeToLevelUp

    static let closeToLevelUpPhrases: [String] = [
        "[COUNT] notes are close to levelling up — a focused session would move them.",
        "You're one good session away from [COUNT] tier promotions.",
        "[NOTE] on the [STRING] string needs just a few more clean reps.",
        "[COUNT] notes are right on the edge of the next tier. FretShed is watching them.",
    ]

    // MARK: - coldSpot (challenge framing, never failure framing)

    static let coldSpotPhrases: [String] = [
        "[NOTE] on the [STRING] string is stubborn. That's normal — some notes take longer.",
        "[NOTE] keeps coming up. FretShed is drilling it because the data says it needs it.",
        "Stubborn note: [NOTE] on [STRING]. This is the hard part — you're in it.",
        "[NOTE] on [STRING] hasn't moved yet. FretShed will keep at it.",
    ]

    // MARK: - coverage

    static let coveragePhrases: [String] = [
        "You've now attempted every [NOTE_TYPE] on the [STRING] string at least once.",
        "[COUNT] new positions mapped this session. The picture is filling in.",
        "First contact with [NOTE] on the [STRING] string today. FretShed has it logged.",
        "[COUNT] positions tried for the first time. The fretboard is opening up.",
    ]

    // MARK: - sessionDelta (positive)

    static let sessionDeltaPositivePhrases: [String] = [
        "Up [DELTA]% from last session. The work is adding up.",
        "Best accuracy in [N] sessions. Something clicked today.",
        "[ACCURACY]% today vs [PREV]% last time. That's the direction.",
        "You were [PREV]% last session. Today: [ACCURACY]%. Keep coming back.",
    ]

    // MARK: - sessionDelta (negative)

    static let sessionDeltaNegativePhrases: [String] = [
        "Down a bit from last session — that's normal when FretShed pushes harder.",
        "Accuracy dipped, but FretShed was targeting tougher spots this time.",
        "Tougher session. FretShed adjusts difficulty based on what you've mastered.",
        "Lower accuracy today — that means you were practicing the hard stuff.",
    ]

    // MARK: - knowledgeShapeMilestone

    static let knowledgeShapeMilestonePhrases: [String] = [
        "You've pushed past open position. FretShed is now mapping your whole neck.",
        "You've moved past what chord shapes taught you. This is new territory — stay with it.",
        "You've cracked the upper neck. That's a real milestone.",
        "The B string used to be blank. Now FretShed has data on it. Keep going.",
    ]

    // MARK: - Struggling Phase Framing

    static let strugglingFramingPhrases: [String] = [
        "Red means FretShed is still learning your patterns — not that you're bad at this.",
        "This is the mapping phase. Red cells are being measured, not judged.",
        "Every wrong answer is data. FretShed is building your picture.",
    ]

    // MARK: - Shed Forward Prompts

    static let shedWeakStringPhrases: [String] = [
        "Your [STRING] string is waiting.",
        "[STRING] string — that's where FretShed is starting today.",
        "FretShed wants to work on your [STRING] string.",
        "Pick up where you left off: [STRING] string.",
    ]

    static let shedGenericPrompts: [String] = [
        "Ready for another round?",
        "The fretboard doesn't learn itself.",
        "Your next session is ready.",
        "Time to put in the reps.",
    ]

    // MARK: - Continuity Line

    static let continuityLinePhrases: [String] = [
        "Last session, FretShed focused on [STRING] string. It's starting there again today.",
        "Picking up from last time — [STRING] string was the focus.",
        "FretShed remembers: [STRING] string was where you left off.",
        "Continuing from your last session on the [STRING] string.",
    ]

    // MARK: - Session 3 Recalibration

    static let recalibrationMessage =
        "FretShed has updated your starting point based on what it's seen in your first few sessions. It knows you better now."

    // MARK: - Free Tier Upsell

    static let freeTierUpsellMessage =
        "FretShed has mapped strings 4–6. Unlock Premium to train your full neck."

    // MARK: - Temporal Context Modifiers

    struct TemporalModifier {
        let prefix: String
        let isStandalone: Bool // true = separate line before insight
    }

    static func temporalModifier(
        sessionCount: Int,
        allSessions: [Session],
        currentWeakString: Int?,
        lastWeakString: Int?,
        daysSinceLastSession: Int
    ) -> TemporalModifier? {
        // Check conditions in order — first match wins
        if sessionCount == 1 {
            return TemporalModifier(prefix: "First look at your fretboard:", isStandalone: false)
        }
        if daysSinceLastSession >= 3 {
            return TemporalModifier(prefix: "Welcome back.", isStandalone: true)
        }
        if let current = currentWeakString, let last = lastWeakString {
            if current == last {
                // Check if improved
                if allSessions.count >= 2 {
                    let prev = allSessions[allSessions.count - 2]
                    let curr = allSessions[allSessions.count - 1]
                    if curr.accuracyPercent > prev.accuracyPercent {
                        return TemporalModifier(prefix: "Getting better, still your focus —", isStandalone: false)
                    }
                }
                return TemporalModifier(prefix: "Still your focus zone —", isStandalone: false)
            } else {
                return TemporalModifier(prefix: "New territory:", isStandalone: false)
            }
        }
        // Best accuracy in last 7 days — must be strictly better than all prior sessions
        if allSessions.count >= 2 {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recentSessions = allSessions.filter { ($0.endTime ?? $0.startTime) >= weekAgo }
            if let current = allSessions.last {
                // Exclude the current session when comparing
                let priorRecent = recentSessions.filter { $0.id != current.id }
                let priorMax = priorRecent.map(\.accuracyPercent).max() ?? 0
                if !priorRecent.isEmpty && current.accuracyPercent > priorMax {
                    return TemporalModifier(prefix: "Your best session this week —", isStandalone: false)
                }
            }
        }
        return nil
    }

    // MARK: - Known Hard Positions

    /// When an insight targets one of these positions, append a normalising
    /// clause for sessions 1–10. Drop it after session 11+.
    static let knownHardPositions: [String: String] = [
        "B_string": "The B string breaks every pattern from the lower strings. Almost every guitarist struggles here.",
        "F#_inner": "F# on inner strings trips up most players — the irregular B string tuning is why.",
        "Bb_inner": "Bb on the G and D strings is one of the least-visited spots on the fretboard.",
        "upper_frets": "Upper fret notes take longer — most guitarists spend less time up there.",
    ]

    /// Returns a normalising clause if the note/string is a known hard position.
    static func normalisingClause(note: MusicalNote, string: Int, sessionCount: Int) -> String? {
        guard sessionCount <= 10 else { return nil }
        if string == 2 { return knownHardPositions["B_string"] }
        if note == .fSharp && (2...5).contains(string) { return knownHardPositions["F#_inner"] }
        if note == .aSharp && (3...4).contains(string) { return knownHardPositions["Bb_inner"] }
        return nil
    }
}
