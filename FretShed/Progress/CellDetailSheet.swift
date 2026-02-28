// CellDetailSheet.swift
// FretShed — Presentation Layer (Phase 4)

import SwiftUI

struct CellDetailSheet: View {

    let detail: CellDetail

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat

    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    private var score: MasteryScore? { detail.score }
    private var masteryValue: Double {
        score?.score ?? (MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta))
    }
    private var level: MasteryLevel { MasteryLevel.from(score: masteryValue, isMastered: score?.isMastered ?? false) }

    private static let stringNames: [Int: String] = [
        1: "String 1 (high e)", 2: "String 2 (B)", 3: "String 3 (G)",
        4: "String 4 (D)",      5: "String 5 (A)", 6: "String 6 (low E)"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(spacing: 4) {
                    Text(detail.note.displayName(format: noteFormat))
                        .font(DesignSystem.Typography.quizNote)
                        .foregroundStyle(levelColor)
                    Text(Self.stringNames[detail.string] ?? "String \(detail.string)")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
                .padding(.top, 8)

                HStack(spacing: 24) {
                    MasteryRing(value: masteryValue, level: level)
                        .frame(width: 90, height: 90)

                    VStack(alignment: .leading, spacing: 6) {
                        badgeRow(icon: "graduationcap.fill",
                                 label: level.localizedLabel, color: levelColor)
                        if let s = score {
                            badgeRow(icon: "number",
                                     label: "\(s.totalAttempts) attempts", color: DesignSystem.Colors.text2)
                            badgeRow(icon: "checkmark",
                                     label: "\(s.correctAttempts) correct", color: DesignSystem.Colors.correct)
                            badgeRow(icon: "flame.fill",
                                     label: "Best streak: \(s.bestStreakCount)", color: DesignSystem.Colors.amber)
                        } else {
                            Text("Not attempted yet")
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.muted)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let s = score, s.totalAttempts > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.text2)
                            Spacer()
                            Text("\(Int(masteryValue * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(levelColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(DesignSystem.Colors.surface2)
                                Capsule().fill(levelColor)
                                    .frame(width: geo.size.width * masteryValue)
                                    .animation(.spring(duration: 0.6), value: masteryValue)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 20)
                }

                if !detail.recentAttempts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT ATTEMPTS")
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.text2)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(detail.recentAttempts.enumerated()),
                                    id: \.offset) { idx, attempt in
                                AttemptRow(attempt: attempt, noteFormat: noteFormat)
                                if idx < detail.recentAttempts.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(DesignSystem.Colors.surface,
                                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .background(DesignSystem.Colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var levelColor: Color {
        DesignSystem.Colors.masteryColor(for: masteryValue)
    }

    private func badgeRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label).font(.subheadline)
        }
    }
}

// MARK: - MasteryRing

private struct MasteryRing: View {
    let value: Double
    let level: MasteryLevel

    private var ringColor: Color {
        DesignSystem.Colors.masteryColor(for: value)
    }

    var body: some View {
        ZStack {
            Circle().stroke(ringColor.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: value)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.7), value: value)
            VStack(spacing: 0) {
                Text("\(Int(value * 100))")
                    .font(DesignSystem.Typography.screenTitle)
                    .monospacedDigit()
                Text("%")
                    .font(DesignSystem.Typography.microLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }
}

// MARK: - AttemptRow

private struct AttemptRow: View {
    let attempt: Attempt
    let noteFormat: NoteNameFormat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attempt.wasCorrect
                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(attempt.wasCorrect ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                if let played = attempt.playedNote, !attempt.wasCorrect {
                    Text("Played \(played.displayName(format: noteFormat))")
                        .font(.subheadline)
                } else if attempt.wasCorrect {
                    Text("Correct").font(.subheadline)
                } else {
                    Text("Timeout / miss")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }
                Text(attempt.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.muted)
            }

            Spacer()

            Text("\(attempt.responseTimeMs) ms")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
