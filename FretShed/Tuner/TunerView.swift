//
//  TunerView.swift
//  FretShed
//
//  Created by John Mulligan on 2/15/26.
//


// TunerView.swift
// FretShed — Presentation Layer (Phase 5)

import SwiftUI

// MARK: - TunerView

public struct TunerView: View {

    @Environment(\.appContainer) private var container

    @State private var detector = PitchDetector()
    @State private var settings: UserSettings? = nil
    @State private var displayCents: Double = 0
    @Environment(\.verticalSizeClass) private var vSizeClass

    // displayStyle and referenceAHz kept in @AppStorage so the tuner tab
    // reflects the same values as the Settings screen immediately.
    @AppStorage("tunerDisplayStyle") private var displayStyleRaw: String = TunerDisplayStyle.needle.rawValue
    private var displayStyle: TunerDisplayStyle {
        TunerDisplayStyle(rawValue: displayStyleRaw) ?? .needle
    }

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat
    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    @AppStorage("referenceAHz") private var referenceAHz: Int = 440

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                if vSizeClass == .compact {
                    // ── Landscape: note header left, display + controls right ──
                    HStack(spacing: 0) {
                        VStack(spacing: 12) {
                            Spacer()
                            noteHeader
                            centsReadout
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        Divider().padding(.vertical, 20)

                        VStack(spacing: 0) {
                            NeedleDisplay(cents: displayCents,
                                              isActive: detector.detectedNote != nil)
                                .padding(.top, 12)
                                .animation(.easeInOut(duration: 0.15), value: displayCents)

                            CentsScale()
                                .padding(.top, 8)
                                .padding(.horizontal, 40)

                            InputLevelBar(level: detector.inputLevel)
                                .padding(.top, 6)
                                .padding(.horizontal, 40)

                            Spacer()

                            controls
                                .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // ── Portrait: original stacked layout ──────────────
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            noteHeader
                                .padding(.top, 24)

                            NeedleDisplay(cents: displayCents,
                                          isActive: detector.detectedNote != nil)
                                .padding(.top, 24)
                                .animation(.easeInOut(duration: 0.15), value: displayCents)

                            centsReadout
                                .padding(.top, 16)

                            CentsScale()
                                .padding(.top, 8)
                                .padding(.horizontal, 24)

                            InputLevelBar(level: detector.inputLevel)
                                .padding(.top, 6)
                                .padding(.horizontal, 24)

                            controls
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                        }
                        .background(DesignSystem.Colors.surface,
                                    in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.top, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                detector.sustainMode = true
                await applySettings()
                try? await detector.start()
            }
            .onDisappear {
                Task { await detector.stop() }
            }
            .onChange(of: referenceAHz) { _, new in
                detector.referenceA = Double(new)
            }
            // Reset displayCents when a NEW note starts (nil → some)
            .onChange(of: detector.detectedNote) { oldNote, newNote in
                if newNote != nil && oldNote == nil {
                    displayCents = detector.centsDeviation
                }
            }
            // During sustained detection, apply amplitude-aware EMA
            .onChange(of: detector.centsDeviation) { _, newCents in
                guard detector.detectedNote != nil else { return }
                let alpha = 0.1 + 0.3 * min(detector.inputLevel, 1.0)
                displayCents = alpha * newCents + (1.0 - alpha) * displayCents
            }
            .alert("Microphone Access Required",
                   isPresented: Binding(
                    get: { detector.error != nil },
                    set: { _ in }
                   )) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(detector.error?.localizedDescription ?? "")
            }
        }
    }

    /// Loads UserSettings and applies them to the detector before starting.
    private func applySettings() async {
        let loaded = try? container.settingsRepository.loadSettings()
        settings = loaded
        if let s = loaded {
            detector.referenceA = Double(s.referenceAHz)
            detector.confidenceThreshold = s.tunerSensitivity
            detector.forceBuiltInMic = s.forceBuiltInMic
            // Mirror stored values into @AppStorage so controls stay in sync.
            referenceAHz = s.referenceAHz
            displayStyleRaw = s.tunerDisplayStyleRaw
        } else {
            detector.referenceA = Double(referenceAHz)
        }
    }

    // MARK: - Note Header

    private var noteHeader: some View {
        VStack(spacing: 6) {
            if let note = detector.detectedNote {
                Text(note.displayName(format: noteFormat))
                    .font(DesignSystem.Typography.noteDisplay)
                    .foregroundStyle(tuningColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: note)

                if let freq = detector.detectedFrequency {
                    Text(String(format: "%.1f Hz", freq))
                        .font(DesignSystem.Typography.centsDisplay)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .contentTransition(.numericText())
                }
            } else if let err = detector.error, case .microphonePermissionDenied = err {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(DesignSystem.Colors.wrong.opacity(0.7))
                Text("Microphone access required")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(DesignSystem.Typography.smallLabel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.cherry.opacity(0.12), in: Capsule())
                        .foregroundStyle(DesignSystem.Colors.cherry)
                }
                .buttonStyle(.plain)
            } else {
                Text("–")
                    .font(DesignSystem.Typography.noteDisplay)
                    .foregroundStyle(DesignSystem.Colors.muted)
                Text(detector.isRunning ? "Play a note…" : "Starting…")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
        .frame(height: 110)
    }

    // MARK: - Cents Readout

    private var centsReadout: some View {
        let c = displayCents
        let sign = c >= 0 ? "+" : ""
        return Text("\(sign)\(Int(c.rounded())) ¢")
            .font(DesignSystem.Typography.subDisplay)
            .foregroundStyle(tuningColor)
            .contentTransition(.numericText())
            .opacity(detector.detectedNote != nil ? 1 : 0)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 6) {
            Image(systemName: "tuningfork")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.text)
            Text("A4 = 440 Hz")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text)
        }
    }

    // MARK: - Colour

    private var tuningColor: Color {
        DesignSystem.Colors.tuningColor(
            centsDeviation: detector.centsDeviation,
            isActive: detector.detectedNote != nil
        )
    }
}

// MARK: - NeedleDisplay

struct NeedleDisplay: View {

    let cents: Double
    let isActive: Bool

    private var angle: Double {
        isActive ? (cents / 50.0) * 90.0 : -90
    }

    var body: some View {
        ZStack {
            DialArc()
                .stroke(DesignSystem.Colors.border, lineWidth: 7)
                .frame(width: 340, height: 170)

            DialArc()
                .trim(from: 0.44, to: 0.56)
                .stroke(DesignSystem.Colors.correct.opacity(0.6), lineWidth: 9)
                .frame(width: 340, height: 170)

            DialTicks()
                .frame(width: 340, height: 170)

            Needle(angle: angle)
                .frame(width: 340, height: 170)
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: angle)

            Circle()
                .fill(DesignSystem.Colors.amber)
                .frame(width: 16, height: 16)
                .offset(y: 85)
        }
        .frame(height: 180)
    }
}

struct DialArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let centre = CGPoint(x: rect.midX, y: rect.maxY)
        p.addArc(center: centre,
                 radius: rect.width / 2,
                 startAngle: .degrees(180),
                 endAngle: .degrees(0),
                 clockwise: false)
        return p
    }
}

struct DialTicks: View {
    var body: some View {
        Canvas { ctx, size in
            let centre = CGPoint(x: size.width / 2, y: size.height)
            let r = size.width / 2
            for i in stride(from: -50, through: 50, by: 10) {
                let angleDeg = 180.0 + Double(i + 50) / 100.0 * 180.0
                let rad = angleDeg * .pi / 180
                let isMajor = i % 50 == 0 || i == 0
                let len: CGFloat = isMajor ? 18 : 10
                let inner = CGPoint(x: centre.x + (r - len) * cos(rad),
                                    y: centre.y + (r - len) * sin(rad))
                let outer = CGPoint(x: centre.x + r * cos(rad),
                                    y: centre.y + r * sin(rad))
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(path,
                           with: .color(DesignSystem.Colors.text),
                           lineWidth: isMajor ? 3 : 2)
            }
        }
    }
}

struct Needle: View {
    let angle: Double

    var body: some View {
        Canvas { ctx, size in
            let centre = CGPoint(x: size.width / 2, y: size.height)
            let length = size.width / 2 - 8
            let totalDeg = 270.0 + angle
            let rad = totalDeg * .pi / 180
            let tip = CGPoint(x: centre.x + length * cos(rad),
                              y: centre.y + length * sin(rad))
            var path = Path()
            path.move(to: centre)
            path.addLine(to: tip)
            ctx.stroke(path, with: .color(DesignSystem.Colors.amber), lineWidth: 3.5)
        }
    }
}

// MARK: - StrobeDisplay

private struct StrobeDisplay: View {

    let cents: Double
    let isActive: Bool

    @State private var animator = StrobeAnimator()
    private let bandCount = 20

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { ctx, size in
                let phase = animator.advance(cents: cents, isActive: isActive)
                let bandWidth = size.width / CGFloat(bandCount)
                for i in 0..<bandCount {
                    var raw = (Double(i) + phase)
                        .truncatingRemainder(dividingBy: 2.0)
                    if raw < 0 { raw += 2.0 }
                    let t = abs(raw - 1.0)
                    let rect = CGRect(
                        x: CGFloat(i) * bandWidth, y: 0,
                        width: bandWidth + 0.5, height: size.height
                    )
                    ctx.fill(Path(rect),
                            with: .color(DesignSystem.Colors.text.opacity(0.15 + 0.7 * t)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
        .frame(height: 80)
        .padding(.horizontal, 40)
    }
}

/// Tracks strobe phase using wall-clock deltas so the animation stays
/// frame-rate independent.  Held by @State as a reference type so phase
/// accumulates across SwiftUI re-renders without triggering extra updates.
private final class StrobeAnimator: @unchecked Sendable {
    private var phase: Double = 0
    private var lastTime: TimeInterval = 0

    func advance(cents: Double, isActive: Bool) -> Double {
        let now = ProcessInfo.processInfo.systemUptime
        if isActive {
            if lastTime > 0 {
                let dt = min(now - lastTime, 0.1)
                phase += cents * dt * 0.45
            }
        } else {
            phase = 0
        }
        lastTime = now
        return phase
    }
}

// MARK: - CentsScale

struct CentsScale: View {
    var body: some View {
        HStack {
            Text("-50¢").font(.callout.weight(.medium)).foregroundStyle(DesignSystem.Colors.text)
            Spacer()
            Text("0").font(.callout.weight(.bold)).foregroundStyle(DesignSystem.Colors.correct)
            Spacer()
            Text("+50¢").font(.callout.weight(.medium)).foregroundStyle(DesignSystem.Colors.text)
        }
    }
}

// MARK: - InputLevelBar

struct InputLevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * CGFloat(level)

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.surface2)

                // Filled bar with 3 color zones
                HStack(spacing: 0) {
                    let greenEnd = min(fillWidth, width * 0.6)
                    let yellowEnd = min(max(fillWidth - width * 0.6, 0), width * 0.25)
                    let redEnd = max(fillWidth - width * 0.85, 0)

                    if greenEnd > 0 {
                        Color.green
                            .frame(width: greenEnd)
                    }
                    if yellowEnd > 0 {
                        Color.yellow
                            .frame(width: yellowEnd)
                    }
                    if redEnd > 0 {
                        Color.red
                            .frame(width: redEnd)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Labels
                if level < 0.05 {
                    Text("Audio Level")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else if level > 0.95 {
                    Text("CLIP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 22)
        .animation(.spring(response: 0.15, dampingFraction: 1.0), value: level)
    }
}

// MARK: - Preview

#Preview {
    TunerView()
}
