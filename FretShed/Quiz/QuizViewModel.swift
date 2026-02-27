// QuizViewModel.swift
// FretShed — Presentation Layer

import Foundation
import OSLog
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
    /// When true, countdown ticks are silenced (user-toggled mute button).
    public var isTimerMuted: Bool = false
    public private(set) var detectedNote: MusicalNote?
    /// Current per-question time budget for Tempo mode (shrinks with each correct answer).
    public private(set) var tempoTimeAllowance: Double = 10

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
    /// Current position in the circle of fourths/fifths sequence (0 = C).
    /// Only used when focusMode is .circleOfFourths or .circleOfFifths.
    private var circleNoteIndex: Int = 0
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

    /// Response times (ms) for correct answers only — used to compute average for timed sessions.
    private var correctResponseTimes: [Int] = []

    private static let feedbackDuration: TimeInterval = 1.5
    private static let timerInterval: TimeInterval = 0.05
    /// Tempo mode: each correct answer shaves this many seconds off the allowance.
    private static let tempoDecrement: Double = 0.5
    /// Tempo mode: the allowance will never drop below this floor (seconds).
    private static let tempoFloor: Double = 2.0
    /// Feedback duration for the chord completion summary (untimed only).
    private static let chordCompleteFeedbackDuration: TimeInterval = 2.5

    // MARK: - Initializer

    public init(
        session: Session,
        fretboardMap: FretboardMap,
        settings: UserSettings,
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        attemptRepository: any AttemptRepository
    ) {
        self.id = UUID()
        self.session = session
        self.fretboardMap = fretboardMap
        self.settings = settings
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.attemptRepository = attemptRepository
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
        // Initialise tempo allowance from settings so it resets cleanly on each session.
        tempoTimeAllowance = Double(settings.defaultTimerDuration)
        advanceToNextQuestion()
    }

    public func submit(detectedNote note: MusicalNote) {
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
                MetroDroneEngine.shared.playSoundCue(.correct, volume: settings.correctSoundVolume)
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
                        // Timed / tempo: advance immediately.
                        chordToneIndex = 0
                        answeredChordTones = []
                        chordIndex = (chordIndex + 1) % chordCount
                    }
                }
            }
            // Tempo mode: tighten the per-question budget after each correct answer.
            if session.gameMode == .tempo {
                tempoTimeAllowance = max(Self.tempoFloor,
                                        tempoTimeAllowance - Self.tempoDecrement)
            }
        } else {
            currentStreak = 0
            phase = .feedbackWrong
            if settings.hapticFeedbackEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            if settings.incorrectSoundEnabled {
                MetroDroneEngine.shared.playSoundCue(.incorrect, volume: settings.correctSoundVolume)
            }
        }
        timerTask?.cancel()
        Task { recordAttempt(question: question, playedNote: note, correct: correct, responseMs: responseMs) }
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

    public func endSession() async {
        feedbackTask?.cancel()
        timerTask?.cancel()
        phase = .complete
        finaliseSession()
    }

    public func discardSession() async {
        feedbackTask?.cancel()
        timerTask?.cancel()
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
        let question = selectQuestion()
        currentQuestion = question
        lastQuestion = question
        questionStartTime = Date()
        phase = .active
        switch session.gameMode {
        case .timed:
            timeRemaining = Double(settings.defaultTimerDuration)
            startTimer()
        case .tempo:
            timeRemaining = tempoTimeAllowance
            startTimer()
        case .untimed, .streak:
            break
        }
    }

    private func advanceOrComplete() {
        if attemptCount >= settings.defaultSessionLength {
            phase = .complete
            finaliseSession()
        } else {
            advanceToNextQuestion()
        }
    }

    private func selectQuestion() -> QuizQuestion {
        // Circle modes use strict ordering instead of mastery-weighted random selection.
        switch session.focusMode {
        case .circleOfFourths:
            return selectCircleQuestion(from: MusicalNote.circleOfFourths)
        case .circleOfFifths:
            return selectCircleQuestion(from: MusicalNote.circleOfFifths)
        case .chordProgression:
            return selectChordProgressionQuestion()
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

        for (candidate, weight) in zip(pool, weights) {
            r -= weight
            if r <= 0 {
                if let last = lastQuestion,
                   last.note == candidate.note && last.string == candidate.string,
                   pool.count > 1 { continue }
                return candidate
            }
        }
        return pool.last ?? QuizQuestion(note: .e, string: 1, fret: 0)
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

    private func buildCandidates() -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let fretStart = session.fretRangeStart
        let fretEnd   = session.fretRangeEnd
        for stringNum in 1...kStringCount {
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
        case .circleOfFourths, .circleOfFifths:
            // Handled in selectCircleQuestion; fall through to all candidates.
            return candidates
        case .fullFretboard, .chordProgression, .fretboardPosition:
            return candidates
        }
    }

    private func masteryScore(for question: QuizQuestion) -> Double {
        guard let score = allScores.first(where: {
            $0.noteRaw == question.note.rawValue && $0.stringNumber == question.string
        }) else {
            return MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
        }
        return score.score
    }

    // MARK: - Private: Timer

    private func startTimer() {
        timerTask?.cancel()
        // Play an initial countdown tick when the timer starts.
        if !isTimerMuted {
            MetroDroneEngine.shared.playCountdownTick(volume: settings.metronomeVolume)
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
                        MetroDroneEngine.shared.playCountdownTick(volume: settings.metronomeVolume)
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

    private func recordAttempt(question: QuizQuestion, playedNote: MusicalNote, correct: Bool, responseMs: Int) {
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
            acceptedAnyString: settings.defaultNoteAcceptanceMode == .anyString
        )
        do { try attemptRepository.save(attempt) } catch {
            logger.error("Failed to save attempt: \(error)")
        }
        do {
            let score = try masteryRepository.score(forNote: question.note, string: question.string)
            score.record(wasCorrect: correct)
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
        session.endTime = Date()
        do { try sessionRepository.complete(session) } catch {
            logger.error("Failed to complete session: \(error)")
        }
    }
}
