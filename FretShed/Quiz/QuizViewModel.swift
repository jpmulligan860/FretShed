// QuizViewModel.swift
// FretShed — Presentation Layer

import Foundation
import OSLog
import TelemetryDeck
import UIKit

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "QuizViewModel")

// MARK: - QuizPhase

public enum QuizPhase: Equatable {
    case idle
    case active
    case feedbackCorrect
    case feedbackWrong
    case complete
}

// MARK: - QuizQuestion

public struct QuizQuestion: Equatable {
    public let note: MusicalNote
    public let string: Int
    public let fret: Int
}

// MARK: - QuizViewModel

@MainActor
@Observable
public final class QuizViewModel: Identifiable {

    // MARK: - Identifiable
    public nonisolated let id: UUID

    // MARK: - Public State
    public private(set) var phase: QuizPhase = .idle
    public private(set) var currentQuestion: QuizQuestion?
    public private(set) var attemptCount: Int = 0
    public private(set) var correctCount: Int = 0
    public private(set) var currentStreak: Int = 0
    public private(set) var bestStreak: Int = 0
    public private(set) var timeRemaining: Double = 0
    public private(set) var lastAnswerWasCorrect: Bool = false
    /// True when the user chose "End & Delete" — session data was discarded.
    public private(set) var wasDiscarded: Bool = false
    /// When true, countdown ticks are silenced (user-toggled mute button).
    public var isTimerMuted: Bool = false
    public private(set) var detectedNote: MusicalNote?
    /// Current per-question time budget (legacy Tempo mode property, retained for backward compat).
    public private(set) var tempoTimeAllowance: Double = 10
    /// Remaining seconds for timed practice sessions (nil = no session time limit).
    public private(set) var sessionTimeRemaining: Double?

    // MARK: - Adaptive Tracking
    /// Number of questions that targeted positions with mastery < 50%.
    public private(set) var weakSpotQuestionCount: Int = 0
    /// Per-string count of weak-spot questions (string number → count).
    public private(set) var weakSpotsTargetedStrings: [Int: Int] = [:]
    /// True once enough mastery data exists for the current session's candidate positions
    /// to meaningfully differentiate weak from strong.
    public var hasBaselineMastery: Bool {
        let candidates = filter(candidates: buildCandidates())
        return candidates.contains { c in
            allScores.contains {
                $0.noteRaw == c.note.rawValue && $0.stringNumber == c.string && $0.totalAttempts >= 5
            }
        }
    }

    /// Average response time in milliseconds for correct answers only.
    public var averageResponseTimeMs: Int {
        guard !correctResponseTimes.isEmpty else { return 0 }
        return correctResponseTimes.reduce(0, +) / correctResponseTimes.count
    }

    // MARK: - Configuration
    public let session: Session
    public let fretboardMap: FretboardMap
    /// Live reference to the SwiftData model. Safe because the quiz is a full-screen
    /// overlay that hides the Settings tab — the user cannot modify settings mid-quiz.
    /// The coordinator also mutates `tapToAnswerEnabled` before/after the quiz, which
    /// requires a live reference rather than a frozen snapshot.
    public let settings: UserSettings

    // MARK: - Private State
    private let masteryRepository: any MasteryRepository
    private let sessionRepository: any SessionRepository
    private let attemptRepository: any AttemptRepository
    private var allScores: [MasteryScore] = []
    private var lastQuestion: QuizQuestion?
    private var questionStartTime: Date = Date()
    private var feedbackTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var sessionTimerTask: Task<Void, Never>?
    /// Current position in the circle of fourths/fifths sequence (0 = C).
    /// Only used when focusMode is .circleOfFourths or .circleOfFifths.
    private var circleNoteIndex: Int = 0

    // MARK: - Accuracy Assessment Tracking
    /// Index into the string sequence (0 = string 6, 1 = string 5, …, 5 = string 1).
    /// Only used when focusMode is .accuracyAssessment.
    private var assessmentStringIndex: Int = 0
    /// Current fret within the active string. Advances from fretRangeStart to fretRangeEnd.
    private var assessmentFretIndex: Int = 0
    /// Current repetition within the current cell (0, 1, 2). Resets when advancing to next cell.
    private var assessmentRepIndex: Int = 0
    /// Number of times each cell is played during an accuracy assessment.
    private static let assessmentRepsPerCell = 3
    /// Per-cell results: key = "string-fret", value = array of wasCorrect bools (one per rep).
    private var assessmentCellResultsStore: [String: [Bool]] = [:]
    /// Index of the current chord in the chord progression (0-based).
    private var chordIndex: Int = 0
    /// Index of the current tone within the chord: 0 = root, 1 = third, 2 = fifth.
    private var chordToneIndex: Int = 0
    /// The fret chosen for the root of the current chord triad, used to keep
    /// the 3rd and 5th physically close on the fretboard (close voicing).
    private var chordRootFret: Int? = nil
    private var chordRootString: Int? = nil

    // MARK: - Chord Progression Public Context
    /// The current chord being drilled, for display in the UI.
    public private(set) var currentChord: ChordSlot? = nil
    /// The current tone step label ("Root", "3rd", "5th"), for display in the UI.
    public private(set) var currentToneLabel: String = ""
    /// Correctly-answered tones for the current chord, displayed as persistent dots.
    public private(set) var answeredChordTones: [QuizQuestion] = []
    /// True while displaying the completed chord summary (untimed only).
    /// The UI uses this alongside `currentChord` to show chord name and notes.
    public private(set) var showingChordCompleteSummary: Bool = false

    /// Total number of cells in the accuracy assessment (6 × fret count).
    public var assessmentTotalCells: Int {
        guard session.focusMode == .accuracyAssessment else { return 0 }
        return kStringCount * (session.fretRangeEnd - session.fretRangeStart + 1)
    }

    /// 1-based position within the accuracy assessment sequence.
    public var assessmentCurrentPosition: Int {
        let fretCount = session.fretRangeEnd - session.fretRangeStart + 1
        return assessmentStringIndex * fretCount + assessmentFretIndex + 1
    }

    /// 1-based repetition index for the current cell.
    public var assessmentCurrentRep: Int { assessmentRepIndex + 1 }

    /// Number of reps per cell (read-only accessor for the view).
    public var assessmentRepsPerCell: Int { Self.assessmentRepsPerCell }

    /// Total attempts in the assessment (cells × reps).
    public var assessmentTotalAttempts: Int { assessmentTotalCells * Self.assessmentRepsPerCell }

    /// Read-only access to per-cell result arrays for the results view.
    public var assessmentResults: [String: [Bool]] { assessmentCellResultsStore }

    /// Per-string accuracy aggregated from cell results: string number → (correct, total).
    public var assessmentPerStringAccuracy: [Int: (correct: Int, total: Int)] {
        var result: [Int: (correct: Int, total: Int)] = [:]
        for (key, bools) in assessmentCellResultsStore {
            let parts = key.split(separator: "-")
            guard let stringNum = Int(parts.first ?? "") else { continue }
            let correct = bools.filter { $0 }.count
            let existing = result[stringNum, default: (correct: 0, total: 0)]
            result[stringNum] = (correct: existing.correct + correct, total: existing.total + bools.count)
        }
        return result
    }

    /// Count of cells at each consistency level: 0/3, 1/3, 2/3, 3/3.
    /// Key = number correct (0…3), value = count of cells at that level.
    public var assessmentConsistencyBuckets: [Int: Int] {
        var buckets: [Int: Int] = [0: 0, 1: 0, 2: 0, 3: 0]
        for (_, bools) in assessmentCellResultsStore {
            let correct = bools.filter { $0 }.count
            buckets[correct, default: 0] += 1
        }
        return buckets
    }

    // MARK: - Warmup Block State

    /// Pre-built warmup questions served before new content.
    private var warmupQuestions: [QuizQuestion] = []
    /// Number of warmup questions (set once at start, does not change).
    private(set) var warmupQuestionCount: Int = 0
    /// True while the quiz is serving warmup questions (attemptCount < warmupQuestionCount).
    public var isInWarmup: Bool { warmupQuestionCount > 0 && attemptCount < warmupQuestionCount }
    /// True only before the very first warmup question is presented.
    public private(set) var showWarmupIntro: Bool = false

    /// Set of (noteRaw, stringNumber) pairs quizzed in this session, for spacing gate advancement.
    private var quizzedCellKeys: Set<Int> = []

    /// Encodes a (noteRaw, stringNumber) pair into a single Int for Set storage.
    private static func cellKey(noteRaw: Int, string: Int) -> Int {
        noteRaw * 100 + string
    }

    /// Response times (ms) for correct answers only — used to compute average for timed sessions.
    private var correctResponseTimes: [Int] = []

    private static let feedbackDuration: TimeInterval = 1.5
    private static let timerInterval: TimeInterval = 0.05
    /// Feedback duration for the chord completion summary (untimed only).
    private static let chordCompleteFeedbackDuration: TimeInterval = 2.5

    // MARK: - Initializer

    // MARK: - Free Tier Limits
    private let isPremium: Bool
    private static let freeStrings: Set<Int> = [4, 5, 6]
    private static let freeFretMax: Int = 12

    public init(
        session: Session,
        fretboardMap: FretboardMap,
        settings: UserSettings,
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        attemptRepository: any AttemptRepository,
        isPremium: Bool = false
    ) {
        self.id = UUID()
        self.session = session
        self.fretboardMap = fretboardMap
        self.settings = settings
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.attemptRepository = attemptRepository
        self.isPremium = isPremium
    }

    // MARK: - Public Interface

    public func start() {
        guard phase == .idle else { return }
        do {
            allScores = try masteryRepository.allScores()
        } catch {
            logger.error("Failed to load mastery scores: \(error)")
            allScores = []
        }
        TelemetryDeck.signal(AnalyticsEvent.sessionStarted)
        // Build warmup block if 1+ calendar days since last session.
        buildWarmupBlockIfNeeded()
        // Start session countdown timer if a time limit is set.
        if session.sessionTimeLimitSeconds > 0 {
            sessionTimeRemaining = Double(session.sessionTimeLimitSeconds)
            startSessionTimer()
        }
        advanceToNextQuestion()
    }

    public func submit(
        detectedNote note: MusicalNote,
        detectedFrequencyHz: Double? = nil,
        detectedConfidence: Double? = nil,
        centsDeviation: Double? = nil
    ) {
        guard phase == .active, let question = currentQuestion else { return }
        detectedNote = note
        let correct = note == question.note
        let responseMs = Int(Date().timeIntervalSince(questionStartTime) * 1000)
        attemptCount += 1
        session.attemptCount += 1
        lastAnswerWasCorrect = correct
        if correct {
            correctResponseTimes.append(responseMs)
            correctCount += 1
            session.correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            phase = .feedbackCorrect
            if settings.hapticFeedbackEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if settings.correctSoundEnabled {
                MetroDroneEngine.shared.playSoundCue(.correct, volume: 0.7)
            }
            // Advance to the next note in the circle after a correct answer.
            if session.focusMode == .circleOfFourths || session.focusMode == .circleOfFifths {
                circleNoteIndex = (circleNoteIndex + 1) % 12
            }
            // Chord progression: advance tone within chord, then move to next chord.
            if session.focusMode == .chordProgression {
                answeredChordTones.append(currentQuestion!)
                let progression = session.chordProgression ?? ChordProgression.presets[0]
                let chordCount = progression.chords.count
                let toneCount = progression.toneSelection.toneCount
                chordToneIndex += 1
                if chordToneIndex >= toneCount {
                    if session.gameMode == .untimed || session.gameMode == .streak {
                        // Show chord summary — defer advancement to next question.
                        showingChordCompleteSummary = true
                    } else {
                        // Timed: advance immediately.
                        chordToneIndex = 0
                        answeredChordTones = []
                        chordIndex = (chordIndex + 1) % chordCount
                    }
                }
            }
        } else {
            currentStreak = 0
            phase = .feedbackWrong
            if settings.hapticFeedbackEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            if settings.incorrectSoundEnabled {
                MetroDroneEngine.shared.playSoundCue(.incorrect, volume: 0.7)
            }
        }
        timerTask?.cancel()
        Task { recordAttempt(question: question, playedNote: note, correct: correct, responseMs: responseMs, detectedFrequencyHz: detectedFrequencyHz, detectedConfidence: detectedConfidence, centsDeviation: centsDeviation) }
        // Accuracy assessment: record the per-cell result and advance the rep/cell cursor.
        if session.focusMode == .accuracyAssessment {
            let cellKey = "\(question.string)-\(question.fret)"
            assessmentCellResultsStore[cellKey, default: []].append(correct)
            advanceAssessment()
        }
        // Streak mode: one wrong answer ends the session after showing feedback.
        if !correct && session.gameMode == .streak {
            scheduleFeedbackAdvance(thenComplete: true)
            return
        }
        let duration = showingChordCompleteSummary ? Self.chordCompleteFeedbackDuration : nil
        scheduleFeedbackAdvance(duration: duration)
    }

    public func advanceManually() {
        guard phase == .feedbackCorrect || phase == .feedbackWrong else { return }
        feedbackTask?.cancel()
        advanceOrComplete()
    }

    /// Skip the current question in an accuracy assessment (records as a miss).
    public func skipQuestion() {
        guard phase == .active,
              session.focusMode == .accuracyAssessment,
              let question = currentQuestion else { return }
        detectedNote = nil
        lastAnswerWasCorrect = false
        attemptCount += 1
        session.attemptCount += 1
        currentStreak = 0
        let responseMs = Int(Date().timeIntervalSince(questionStartTime) * 1000)
        Task { recordAttempt(question: question, playedNote: question.note.transposed(by: 1), correct: false, responseMs: responseMs) }
        let cellKey = "\(question.string)-\(question.fret)"
        assessmentCellResultsStore[cellKey, default: []].append(false)
        advanceAssessment()
        advanceOrComplete()
    }

    public func endSession() async {
        feedbackTask?.cancel()
        timerTask?.cancel()
        sessionTimerTask?.cancel()
        phase = .complete
        finaliseSession()
    }

    public func discardSession() async {
        feedbackTask?.cancel()
        timerTask?.cancel()
        sessionTimerTask?.cancel()
        do {
            try attemptRepository.deleteAttempts(forSession: session.id)
            try sessionRepository.delete(session)
            // Rebuild mastery from all remaining attempts.
            var allAttempts: [Attempt] = []
            for note in MusicalNote.allCases {
                let batch = try attemptRepository.attempts(forNote: note, limit: nil)
                allAttempts.append(contentsOf: batch)
            }
            try masteryRepository.rebuild(from: allAttempts)
        } catch {
            logger.error("Failed to discard session: \(error)")
        }
        wasDiscarded = true
        phase = .complete
    }

    // MARK: - Private: Question Flow

    private func advanceToNextQuestion() {
        // Complete deferred chord advancement from the summary phase.
        if showingChordCompleteSummary {
            let progression = session.chordProgression ?? ChordProgression.presets[0]
            chordToneIndex = 0
            answeredChordTones = []
            showingChordCompleteSummary = false
            chordIndex = (chordIndex + 1) % progression.chords.count
        }
        // Dismiss warmup intro after first question starts.
        if showWarmupIntro { showWarmupIntro = false }
        // Serve warmup questions before falling back to normal selection.
        let question: QuizQuestion
        if attemptCount < warmupQuestions.count {
            question = warmupQuestions[attemptCount]
        } else {
            question = selectQuestion()
        }
        currentQuestion = question
        lastQuestion = question
        questionStartTime = Date()
        phase = .active
        switch session.gameMode {
        case .timed, .tempo:
            timeRemaining = Double(settings.defaultTimerDuration)
            startTimer()
        case .untimed, .streak:
            break
        }
    }

    private func advanceOrComplete() {
        if session.focusMode == .accuracyAssessment {
            if assessmentStringIndex >= kStringCount {
                phase = .complete
                finaliseSession()
            } else {
                advanceToNextQuestion()
            }
        } else if session.sessionTimeLimitSeconds > 0 {
            // Timed practice: keep going until the session timer expires
            advanceToNextQuestion()
        } else if attemptCount >= settings.defaultSessionLength {
            phase = .complete
            finaliseSession()
        } else {
            advanceToNextQuestion()
        }
    }

    private func selectQuestion() -> QuizQuestion {
        // Modes with strict ordering instead of mastery-weighted random selection.
        switch session.focusMode {
        case .circleOfFourths:
            return selectCircleQuestion(from: MusicalNote.circleOfFourths)
        case .circleOfFifths:
            return selectCircleQuestion(from: MusicalNote.circleOfFifths)
        case .chordProgression:
            return selectChordProgressionQuestion()
        case .accuracyAssessment:
            return selectAssessmentQuestion()
        default:
            break
        }

        let candidates = buildCandidates()
        let filtered = filter(candidates: candidates)
        guard !filtered.isEmpty else { return QuizQuestion(note: .e, string: 1, fret: 0) }

        let pool: [QuizQuestion]
        let weights: [Double]

        if session.isAdaptive {
            // Adaptive weighting: skip mastered cells, heavily weight struggling ones.
            let unmastered = filtered.filter { c in
                guard let score = allScores.first(where: {
                    $0.noteRaw == c.note.rawValue && $0.stringNumber == c.string
                }) else { return true }
                return !score.isMastered
            }
            pool = unmastered.isEmpty ? filtered : unmastered

            weights = pool.map { c -> Double in
                guard let score = allScores.first(where: {
                    $0.noteRaw == c.note.rawValue && $0.stringNumber == c.string
                }) else {
                    // Use baseline prior for unseen cells
                    if let baseline = BaselineLevel.load() {
                        let prior = baseline.priorScore(string: c.string, fret: c.fret)
                        return max(pow(1.0 - prior, 2.0), 0.001)
                    }
                    return 1.0
                }
                if score.isStruggling { return 5.0 }
                return max(pow(1.0 - score.score, 2.0), 0.001)
            }
        } else {
            pool = filtered
            weights = pool.map { c -> Double in
                let score = masteryScore(for: c)
                return max(pow(1.0 - score, 2.0), 0.001)
            }
        }

        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<total)

        var selected: QuizQuestion?
        for (candidate, weight) in zip(pool, weights) {
            r -= weight
            if r <= 0 {
                if let last = lastQuestion,
                   last.note == candidate.note && last.string == candidate.string,
                   pool.count > 1 { continue }
                selected = candidate
                break
            }
        }
        let result = selected ?? pool.last ?? QuizQuestion(note: .e, string: 1, fret: 0)

        // Track adaptive weak-spot targeting (only count positions with real data below 50%).
        if session.isAdaptive, let score = allScores.first(where: {
            $0.noteRaw == result.note.rawValue && $0.stringNumber == result.string
        }), score.score < 0.50 {
            weakSpotQuestionCount += 1
            weakSpotsTargetedStrings[result.string, default: 0] += 1
        }

        return result
    }

    /// Chord Progression mode: strictly drills root → third → fifth for each chord
    /// in the session's chosen ChordProgression, then advances to the next chord.
    /// Falls back to a C-major I–IV–V if no progression was stored on the session.
    private func selectChordProgressionQuestion() -> QuizQuestion {
        let progression = session.chordProgression ?? ChordProgression.presets[0]
        guard !progression.chords.isEmpty else {
            return QuizQuestion(note: .c, string: 1, fret: 0)
        }

        let selection = progression.toneSelection
        let chord = progression.chords[chordIndex % progression.chords.count]
        let selectedTones = chord.selectedTones(for: selection)
        let toneIdx = chordToneIndex % selectedTones.count
        let targetNote = selectedTones[toneIdx]

        // Publish context so the UI can label the prompt correctly.
        currentChord = chord
        currentToneLabel = selection.toneLabels[toneIdx]

        let allCandidates: [QuizQuestion] = {
            let raw = buildCandidates().filter { $0.note == targetNote }
            guard !session.targetStrings.isEmpty else { return raw }
            let stringFiltered = raw.filter { session.targetStrings.contains($0.string) }
            return stringFiltered.isEmpty ? raw : stringFiltered
        }()
        guard !allCandidates.isEmpty else {
            return QuizQuestion(note: targetNote, string: 1, fret: 0)
        }

        // Close voicing: keep the 3rd and 5th within 2 frets and on
        // adjacent strings so the triad is playable as a close-position chord.
        let candidates: [QuizQuestion]
        if toneIdx == 0 {
            // Root: avoid repeating the exact same position.
            let noRepeat = allCandidates.filter { c in
                guard let last = lastQuestion else { return true }
                return !(last.note == c.note && last.string == c.string)
            }
            let pool = noRepeat.isEmpty ? allCandidates : noRepeat

            // Position proximity: constrain root near the previous chord's position.
            if let prevFret = chordRootFret, let prevString = chordRootString {
                let nearby = pool.filter {
                    abs($0.fret - prevFret) <= 4 && abs($0.string - prevString) <= 3
                }
                let wider = nearby.isEmpty ? pool.filter {
                    abs($0.fret - prevFret) <= 6
                } : nearby
                let pick = (wider.isEmpty ? pool : wider).randomElement()!
                chordRootFret = pick.fret
                chordRootString = pick.string
                return pick
            }

            // First chord: pick freely.
            let pick = pool.randomElement()!
            chordRootFret = pick.fret
            chordRootString = pick.string
            return pick
        } else if let rootFret = chordRootFret, let rootString = chordRootString {
            // No two chord tones on the same string — exclude strings already used.
            let usedStrings = Set(answeredChordTones.map(\.string))
            let available = allCandidates.filter { !usedStrings.contains($0.string) }
            let base = available.isEmpty ? allCandidates : available

            // 3rd / 5th: prefer positions within 2 frets AND 2 strings of the root.
            let close = base.filter {
                abs($0.fret - rootFret) <= 2 && abs($0.string - rootString) <= 2
            }
            // Fallback: allow 3 frets if no tight voicing exists.
            let wider = close.isEmpty ? base.filter {
                abs($0.fret - rootFret) <= 3 && abs($0.string - rootString) <= 3
            } : close
            candidates = wider.isEmpty ? base : wider
        } else {
            candidates = allCandidates
        }

        let choices = candidates.filter { c in
            guard let last = lastQuestion else { return true }
            return !(last.note == c.note && last.string == c.string)
        }
        return (choices.isEmpty ? candidates : choices).randomElement()!
    }

    /// Returns a question for the current circle position, picking a random
    /// string/fret that produces the target note. Stays on the same note when
    /// the previous answer was wrong (index is only advanced in `submit`).
    private func selectCircleQuestion(from circle: [MusicalNote]) -> QuizQuestion {
        let targetNote = circle[circleNoteIndex]
        var candidates = buildCandidates().filter { $0.note == targetNote }
        // Constrain to target strings when the user selected specific strings for circles.
        if !session.targetStrings.isEmpty {
            let sf = candidates.filter { session.targetStrings.contains($0.string) }
            if !sf.isEmpty { candidates = sf }
        }
        guard !candidates.isEmpty else { return QuizQuestion(note: targetNote, string: 1, fret: 0) }
        let choices = candidates.filter { c in
            guard let last = lastQuestion else { return true }
            return !(last.note == c.note && last.string == c.string)
        }
        return (choices.isEmpty ? candidates : choices).randomElement()!
    }

    /// Returns the next sequential cell for the accuracy assessment.
    /// Order: string 6 fret 0…N, string 5 fret 0…N, …, string 1 fret 0…N.
    private func selectAssessmentQuestion() -> QuizQuestion {
        let stringNumber = kStringCount - assessmentStringIndex  // 6, 5, 4, 3, 2, 1
        let fret = session.fretRangeStart + assessmentFretIndex
        guard let fretMap = fretboardMap.map[stringNumber],
              let note = fretMap[fret] else {
            return QuizQuestion(note: .e, string: stringNumber, fret: fret)
        }
        return QuizQuestion(note: note, string: stringNumber, fret: fret)
    }

    /// Advance the assessment cursor: increment rep first, then move to next cell after 3 reps.
    private func advanceAssessment() {
        assessmentRepIndex += 1
        if assessmentRepIndex >= Self.assessmentRepsPerCell {
            assessmentRepIndex = 0
            let fretCount = session.fretRangeEnd - session.fretRangeStart + 1
            assessmentFretIndex += 1
            if assessmentFretIndex >= fretCount {
                assessmentFretIndex = 0
                assessmentStringIndex += 1
            }
        }
    }

    private func buildCandidates() -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let fretStart = session.fretRangeStart
        let fretEnd   = isPremium ? session.fretRangeEnd : min(session.fretRangeEnd, Self.freeFretMax)
        for stringNum in 1...kStringCount {
            // Free tier: strings 4–6 only
            if !isPremium && !Self.freeStrings.contains(stringNum) { continue }
            guard let fretMap = fretboardMap.map[stringNum] else { continue }
            for fret in fretStart...fretEnd {
                guard let note = fretMap[fret] else { continue }
                questions.append(QuizQuestion(note: note, string: stringNum, fret: fret))
            }
        }
        return questions
    }

    private func filter(candidates: [QuizQuestion]) -> [QuizQuestion] {
        switch session.focusMode {
        case .singleNote:
            let targetNotes = session.notes.compactMap { MusicalNote(rawValue: $0) }
            if targetNotes.isEmpty { return candidates }
            return candidates.filter { targetNotes.contains($0.note) }
        case .singleString:
            let targetStrings = session.targetStrings
            if targetStrings.isEmpty { return candidates }
            return candidates.filter { targetStrings.contains($0.string) }
        case .naturalNotes:
            let targetStrings = session.targetStrings
            let naturals = candidates.filter { $0.note.isNatural }
            if targetStrings.isEmpty { return naturals }
            return naturals.filter { targetStrings.contains($0.string) }
        case .sharpsAndFlats:
            let sharpsFlatsTargetStrings = session.targetStrings
            let accidentals = candidates.filter { !$0.note.isNatural }
            if sharpsFlatsTargetStrings.isEmpty { return accidentals }
            return accidentals.filter { sharpsFlatsTargetStrings.contains($0.string) }
        case .circleOfFourths, .circleOfFifths:
            // Handled in selectCircleQuestion; fall through to all candidates.
            return candidates
        case .fullFretboard, .chordProgression, .fretboardPosition, .accuracyAssessment:
            return candidates
        }
    }

    private func masteryScore(for question: QuizQuestion) -> Double {
        guard let score = allScores.first(where: {
            $0.noteRaw == question.note.rawValue && $0.stringNumber == question.string
        }) else {
            // Use baseline prior if the user selected one during onboarding
            if let baseline = BaselineLevel.load() {
                return baseline.priorScore(string: question.string, fret: question.fret)
            }
            return MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
        }
        return score.score
    }

    // MARK: - Private: Timer

    private func startSessionTimer() {
        sessionTimerTask = Task {
            while let remaining = sessionTimeRemaining, remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                sessionTimeRemaining = max(0, remaining - 1)
                if sessionTimeRemaining == 0 {
                    // Session time expired — complete after current feedback
                    feedbackTask?.cancel()
                    timerTask?.cancel()
                    phase = .complete
                    finaliseSession()
                    return
                }
            }
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        // Play an initial countdown tick when the timer starts.
        if !isTimerMuted {
            MetroDroneEngine.shared.playCountdownTick(volume: 0.7)
        }
        timerTask = Task {
            var elapsed = 0.0
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(Self.timerInterval))
                guard !Task.isCancelled else { return }
                timeRemaining = max(0, timeRemaining - Self.timerInterval)
                elapsed += Self.timerInterval
                if elapsed >= 1.0 && timeRemaining > 0 {
                    elapsed -= 1.0
                    if !isTimerMuted {
                        MetroDroneEngine.shared.playCountdownTick(volume: 0.7)
                    }
                }
                if timeRemaining == 0 { handleTimeout() }
            }
        }
    }

    private func handleTimeout() {
        guard phase == .active, let question = currentQuestion else { return }
        detectedNote = nil
        lastAnswerWasCorrect = false
        attemptCount += 1
        session.attemptCount += 1
        currentStreak = 0
        phase = .feedbackWrong
        // Record the timeout as a wrong attempt so it appears on heatmaps.
        let responseMs = Int(Date().timeIntervalSince(questionStartTime) * 1000)
        Task { recordAttempt(question: question, playedNote: question.note.transposed(by: 1), correct: false, responseMs: responseMs) }
        // Streak mode: a timeout is also a failure — end after showing feedback.
        if session.gameMode == .streak {
            scheduleFeedbackAdvance(thenComplete: true)
        } else {
            scheduleFeedbackAdvance()
        }
    }

    private func scheduleFeedbackAdvance(thenComplete: Bool = false, duration: TimeInterval? = nil) {
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(duration ?? Self.feedbackDuration))
            guard !Task.isCancelled else { return }
            if thenComplete {
                phase = .complete
                finaliseSession()
            } else {
                advanceOrComplete()
            }
        }
    }

    // MARK: - Private: Persistence

    private func recordAttempt(question: QuizQuestion, playedNote: MusicalNote, correct: Bool, responseMs: Int, detectedFrequencyHz: Double? = nil, detectedConfidence: Double? = nil, centsDeviation: Double? = nil) {
        let attempt = Attempt(
            targetNote: question.note,
            targetString: question.string,
            targetFret: question.fret,
            playedNote: playedNote,
            playedString: nil,
            responseTimeMs: responseMs,
            wasCorrect: correct,
            sessionID: session.id,
            gameMode: session.gameMode,
            acceptedAnyString: settings.defaultNoteAcceptanceMode == .anyString,
            detectedFrequencyHz: detectedFrequencyHz,
            detectedConfidence: detectedConfidence,
            centsDeviation: centsDeviation
        )
        do { try attemptRepository.save(attempt) } catch {
            logger.error("Failed to save attempt: \(error)")
        }
        quizzedCellKeys.insert(Self.cellKey(noteRaw: question.note.rawValue, string: question.string))
        do {
            let score = try masteryRepository.score(forNote: question.note, string: question.string)
            score.record(wasCorrect: correct)
            if !correct {
                score.regressSpacingCheckpoint()
            }
            score.updateBestStreak(bestStreak)
            try masteryRepository.save(score)
            if let idx = allScores.firstIndex(where: {
                $0.noteRaw == question.note.rawValue && $0.stringNumber == question.string
            }) {
                allScores[idx] = score
            } else {
                allScores.append(score)
            }
        } catch {
            logger.error("Failed to update mastery score: \(error)")
        }
    }

    private func finaliseSession() {
        session.overallMasteryAtEnd = MasteryCalculator.overallScore(from: allScores)
        session.isCompleted = true
        TelemetryDeck.signal(AnalyticsEvent.sessionCompleted)
        session.endTime = Date()
        do { try sessionRepository.complete(session) } catch {
            logger.error("Failed to complete session: \(error)")
        }
        advanceSpacingCheckpoints()
    }

    /// After session completion, advance spacing gate checkpoints for quizzed cells
    /// that are at proficient level. Enforces calendar-day gaps between checkpoints.
    private func advanceSpacingCheckpoints() {
        for score in allScores where quizzedCellKeys.contains(Self.cellKey(noteRaw: score.noteRaw, string: score.stringNumber)) {
            if let cp = score.tryAdvanceCheckpoint() {
                logger.info("Spacing checkpoint \(cp) reached for note \(score.noteRaw) string \(score.stringNumber)")
            }
            do { try masteryRepository.save(score) } catch {
                logger.error("Failed to save spacing checkpoint: \(error)")
            }
        }
    }

    /// Dismisses the warmup intro card (called by view on tap or auto-dismiss).
    public func dismissWarmupIntro() {
        showWarmupIntro = false
    }

    // MARK: - Review Block (Always-On Spaced Repetition)

    /// Builds a review block for every Smart Practice session.
    /// Review notes from completed strings are front-loaded before new content.
    /// The intro card ("Let's warm up…") only shows after 1+ calendar day away.
    private func buildWarmupBlockIfNeeded() {
        // Only for adaptive (Smart Practice) sessions — skip custom sessions and assessments.
        guard session.isAdaptive else { return }

        let sessionLength = settings.defaultSessionLength
        let reviewCount = min(max(Int(round(Double(sessionLength) * 0.30)), 3), 10)

        let notes = selectWarmupNotes(count: reviewCount)
        guard !notes.isEmpty else { return }

        warmupQuestions = notes
        warmupQuestionCount = notes.count

        // Show intro card only after 1+ calendar day away.
        if let lastDate = mostRecentCompletedSessionDate() {
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSince >= 1 {
                showWarmupIntro = true
            }
        }

        logger.info("Review block: \(notes.count) notes from completed strings")
    }

    /// Returns the end date of the most recent completed session, or nil if none exist.
    private func mostRecentCompletedSessionDate() -> Date? {
        guard let sessions = try? sessionRepository.recentSessions(limit: 1),
              let last = sessions.first,
              last.isCompleted,
              let endTime = last.endTime else {
            return nil
        }
        return endTime
    }

    /// Selects warmup notes from previously completed strings/phases.
    /// Priority: (1) notes with active checkpoint progression, (2) lowest effective scores.
    /// Spreads across different strings.
    private func selectWarmupNotes(count: Int) -> [QuizQuestion] {
        let phaseManager = LearningPhaseManager()
        let completedStrings = completedStringsForWarmup(phaseManager: phaseManager)
        guard !completedStrings.isEmpty else { return [] }

        // Gather candidate scores from completed strings that have been practiced.
        let candidates: [(score: MasteryScore, fret: Int)] = allScores.compactMap { score in
            guard completedStrings.contains(score.stringNumber),
                  score.totalAttempts > 0,
                  let note = MusicalNote(rawValue: score.noteRaw),
                  let fret = fretboardMap.fret(for: note, onString: score.stringNumber,
                                                inRange: 0...LearningPhaseManager.phaseRequiredFretEnd)
            else { return nil }
            return (score, fret)
        }

        guard !candidates.isEmpty else { return [] }

        // Sort by priority: active checkpoint progression first, then lowest effective score.
        let sorted = candidates.sorted { a, b in
            let aActive = a.score.hasActiveCheckpointProgression
            let bActive = b.score.hasActiveCheckpointProgression
            if aActive != bActive { return aActive }
            return a.score.effectiveScore < b.score.effectiveScore
        }

        // Pick up to `count` notes, spreading across strings.
        var selected: [QuizQuestion] = []
        var usedStrings: [Int: Int] = [:]  // string → count
        let maxPerString = max(count / completedStrings.count, 1)

        for (score, fret) in sorted {
            guard selected.count < count else { break }
            let stringCount = usedStrings[score.stringNumber, default: 0]
            if stringCount >= maxPerString && selected.count + (count - selected.count) > 1 {
                continue  // Try to spread across strings first
            }
            guard let note = MusicalNote(rawValue: score.noteRaw) else { continue }
            selected.append(QuizQuestion(note: note, string: score.stringNumber, fret: fret))
            usedStrings[score.stringNumber, default: 0] += 1
        }

        // If spreading left us short, fill remaining from top priorities.
        if selected.count < count {
            for (score, fret) in sorted {
                guard selected.count < count else { break }
                guard let note = MusicalNote(rawValue: score.noteRaw) else { continue }
                let q = QuizQuestion(note: note, string: score.stringNumber, fret: fret)
                if !selected.contains(q) {
                    selected.append(q)
                }
            }
        }

        return selected
    }

    /// Returns the set of strings the user has already completed in earlier phases,
    /// excluding the current learning target.
    private func completedStringsForWarmup(phaseManager: LearningPhaseManager) -> Set<Int> {
        var completed = phaseManager.phaseOneCompletedStrings
        // In Phase 2+, Phase 1 completed strings are valid review targets.
        // In Phase 3+, Phase 2 completed strings are also valid.
        if phaseManager.currentPhase.rawValue >= LearningPhase.connection.rawValue {
            completed.formUnion(phaseManager.phaseTwoCompletedStrings)
        }
        // Exclude the current target string (don't review what we're actively learning).
        if let target = phaseManager.currentTargetString {
            completed.remove(target)
        }
        if let target = phaseManager.currentPhaseTwoTargetString {
            completed.remove(target)
        }
        return completed
    }
}
