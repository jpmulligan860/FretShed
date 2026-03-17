//
//  TunerView.swift
//  FretShed
//
//  Created by John Mulligan on 2/15/26.
//


// TunerView.swift
// FretShed — Presentation Layer (Phase 5)

import SwiftUI
import AVFoundation

// MARK: - Guitar String Matching

private struct GuitarStringInfo {
    let number: Int         // 1–6 (1 = high E, 6 = low E)
    let label: String       // "E2", "A2", etc.
    let openFrequency: Double
}

private let standardStrings: [GuitarStringInfo] = [
    GuitarStringInfo(number: 6, label: "E2", openFrequency: 82.41),
    GuitarStringInfo(number: 5, label: "A2", openFrequency: 110.00),
    GuitarStringInfo(number: 4, label: "D3", openFrequency: 146.83),
    GuitarStringInfo(number: 3, label: "G3", openFrequency: 196.00),
    GuitarStringInfo(number: 2, label: "B3", openFrequency: 246.94),
    GuitarStringInfo(number: 1, label: "E4", openFrequency: 329.63),
]

/// Returns the nearest open string if the detected frequency is within ~1.5 semitones.
private func nearestOpenString(frequency: Double) -> GuitarStringInfo? {
    var best: GuitarStringInfo?
    var bestDistance = Double.infinity
    for s in standardStrings {
        let semitones = abs(12.0 * log2(frequency / s.openFrequency))
        if semitones < bestDistance {
            bestDistance = semitones
            best = s
        }
    }
    // Only show if within ~1.5 semitones of an open string
    guard bestDistance <= 1.5 else { return nil }
    return best
}

// MARK: - TunerView

public struct TunerView: View {

    @Environment(\.appContainer) private var container

    @State private var detector = PitchDetector()
    @State private var settings: UserSettings? = nil
    @State private var displayEngine = TunerDisplayEngine()
    @State private var showLatencyWarning = false
    @State private var showMicAlert = false
    @State private var tuningState: TuningState = .noSignal
    @State private var showLevelBar = true
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.colorScheme) private var colorScheme

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
                // Background with color wash
                DesignSystem.Colors.background.ignoresSafeArea()
                backgroundWash.ignoresSafeArea()

                if vSizeClass == .compact {
                    // ── Landscape: note header left, display + controls right ──
                    VStack(spacing: 0) {
                        if showLatencyWarning {
                            latencyWarningBanner
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                        }
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
                                AnimatedNeedleView(displayEngine: displayEngine,
                                                   isActive: detector.detectedNote != nil,
                                                   tuningState: tuningState)
                                    .padding(.top, 12)

                                CentsScale()
                                    .padding(.top, 8)
                                    .padding(.horizontal, 40)

                                InputLevelBar(level: detector.inputLevel)
                                    .padding(.top, 6)
                                    .padding(.horizontal, 40)
                                    .opacity(showLevelBar ? 1 : 0)

                                Spacer()

                                controls
                                    .padding(.bottom, 16)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // ── Portrait: original stacked layout ──────────────
                    VStack(spacing: 16) {
                        if showLatencyWarning {
                            latencyWarningBanner
                                .padding(.horizontal, 16)
                        }

                        VStack(spacing: 0) {
                            noteHeader
                                .padding(.top, 24)

                            AnimatedNeedleView(displayEngine: displayEngine,
                                               isActive: detector.detectedNote != nil,
                                               tuningState: tuningState)
                                .padding(.top, 24)

                            centsReadout
                                .padding(.top, 16)

                            CentsScale()
                                .padding(.top, 8)
                                .padding(.horizontal, 24)

                            InputLevelBar(level: detector.inputLevel)
                                .padding(.top, 6)
                                .padding(.horizontal, 24)
                                .opacity(showLevelBar ? 1 : 0)

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
                // Only start if mic permission already granted — don't trigger
                // the system prompt here. Mic permission is first requested
                // during audio calibration.
                let status = AVAudioApplication.shared.recordPermission
                guard status == .granted else { return }
                try? await detector.start()
                // Check for high-latency input (e.g. Bluetooth)
                let inputLatency = AVAudioSession.sharedInstance().inputLatency
                if inputLatency > 0.05 {
                    showLatencyWarning = true
                }
            }
            .onDisappear {
                Task { await detector.stop() }
            }
            .onChange(of: referenceAHz) { _, new in
                detector.referenceA = Double(new)
            }
            // Feed pitch data into the display engine's interpolation buffer.
            .onChange(of: detector.centsDeviation) { _, newCents in
                guard detector.detectedNote != nil else { return }
                let noteName = detector.detectedNote?.displayName(format: noteFormat)
                displayEngine.pushSample(cents: newCents, note: noteName)
                // Read tuning state from engine (updated during TimelineView's update())
                let newState = displayEngine.tuningState
                if newState != tuningState {
                    let oldState = tuningState
                    tuningState = newState
                    handleStateTransition(from: oldState, to: newState)
                }
            }
            // When note drops, tell the display engine so the needle holds position.
            .onChange(of: detector.detectedNote) { oldNote, newNote in
                if newNote == nil && oldNote != nil {
                    displayEngine.pushSilence()
                    tuningState = .noSignal
                    // Show level bar again after signal drops
                    withAnimation(.easeIn(duration: 0.5)) {
                        showLevelBar = true
                    }
                }
            }
            .alert("Microphone Access Required",
                   isPresented: $showMicAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(detector.error?.localizedDescription ?? "")
            }
            .onChange(of: detector.error != nil) { _, hasError in
                if hasError { showMicAlert = true }
            }
            .animation(.easeInOut(duration: 0.5), value: tuningState)
        }
    }

    // MARK: - State Transition Handling

    private func handleStateTransition(from old: TuningState, to new: TuningState) {
        // Auto-hide level bar when signal is established
        if old == .noSignal && new != .noSignal {
            // Delay before hiding so user can see the initial level
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard tuningState != .noSignal else { return }
                withAnimation(.easeOut(duration: 0.8)) {
                    showLevelBar = false
                }
            }
        }
    }

    /// Loads UserSettings and calibration profile, applies them to the detector before starting.
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
        // Pre-seed from calibration profile — same as QuizView does.
        // Without this, the tuner starts with default noise floor (0.01)
        // and no input-source-aware processing (no low-freq emphasis).
        if let profile = try? container.calibrationRepository.activeProfile() {
            let gateTrimMultiplier = pow(10.0, profile.userGateTrimDB / 20.0)
            detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier
            // Use profile's input source as fallback; start() will re-detect
            // the actual hardware once the audio session is active.
            detector.calibratedInputSource = profile.inputSource
        }
    }

    // MARK: - Background Color Wash

    private var backgroundWash: some View {
        let opacity: Double = switch tuningState {
        case .noSignal, .outOfRange: 0
        case .approaching: 0
        case .inTune: colorScheme == .dark ? 0.04 : 0.03
        case .settled: colorScheme == .dark ? 0.08 : 0.05
        }
        return DesignSystem.Colors.correct.opacity(opacity)
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
                    .shadow(color: tuningState == .settled
                            ? DesignSystem.Colors.correct.opacity(0.4) : .clear,
                            radius: 8)

                if let freq = detector.detectedFrequency {
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f Hz", freq))
                            .font(DesignSystem.Typography.centsDisplay)
                            .foregroundStyle(DesignSystem.Colors.text)
                            .contentTransition(.numericText())

                        // String indicator
                        if let guitarString = nearestOpenString(frequency: freq) {
                            stringIndicator(guitarString)
                        }
                    }
                }
            } else if !detector.isRunning && AVAudioApplication.shared.recordPermission != .granted {
                Image(systemName: AVAudioApplication.shared.recordPermission == .denied ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AVAudioApplication.shared.recordPermission == .denied
                                    ? DesignSystem.Colors.wrong.opacity(0.7)
                                    : DesignSystem.Colors.muted)
                Text(AVAudioApplication.shared.recordPermission == .denied
                     ? "Microphone access required"
                     : "Run Audio Calibration first")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                if AVAudioApplication.shared.recordPermission == .denied {
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
                    Text("The tuner will be available after setup.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }
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

    // MARK: - String Indicator

    private func stringIndicator(_ info: GuitarStringInfo) -> some View {
        HStack(spacing: 4) {
            Text("\(info.number)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.surface)
                .frame(width: 16, height: 16)
                .background(DesignSystem.Colors.amber, in: Circle())
            Text(info.label)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(DesignSystem.Colors.surface2, in: Capsule())
    }

    // MARK: - Cents Readout

    private var centsReadout: some View {
        let c = detector.centsDeviation
        let isActive = detector.detectedNote != nil
        let isSettled = tuningState == .settled
        return VStack(spacing: 4) {
            Text(String(format: "%+.1f ¢", c))
                .font(DesignSystem.Typography.subDisplay)
                .foregroundStyle(isSettled ? tuningColor.opacity(0.6) : tuningColor)
                .contentTransition(.numericText())

            // Sharp / Flat / In Tune directional label
            Group {
                if tuningState == .settled {
                    Text("IN TUNE")
                        .font(DesignSystem.Typography.subDisplay)
                        .foregroundStyle(DesignSystem.Colors.correct)
                        .shadow(color: DesignSystem.Colors.correct.opacity(0.3), radius: 6)
                } else if abs(c) <= 2.0 {
                    Text("IN TUNE")
                        .font(DesignSystem.Typography.sectionLabel)
                        .foregroundStyle(DesignSystem.Colors.correct)
                } else if c > 2.0 {
                    Text("SHARP ↑")
                        .font(DesignSystem.Typography.sectionLabel)
                        .foregroundStyle(tuningColor)
                } else {
                    Text("FLAT ↓")
                        .font(DesignSystem.Typography.sectionLabel)
                        .foregroundStyle(tuningColor)
                }
            }
            .tracking(1.5)
        }
        .opacity(isActive ? 1 : 0)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 6) {
            Image(systemName: "tuningfork")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text)
            Text("A4 = 440 Hz")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text)
        }
    }

    // MARK: - Latency Warning

    private var latencyWarningBanner: some View {
        HStack {
            Text("High latency input detected. For best accuracy, use the built-in mic or a wired connection.")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            Spacer()
            Button {
                showLatencyWarning = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(DesignSystem.Colors.surface2, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Colour

    private var tuningColor: Color {
        DesignSystem.Colors.tuningColor(
            centsDeviation: detector.centsDeviation,
            isActive: detector.detectedNote != nil
        )
    }
}

// MARK: - AnimatedNeedleView

/// Drives the needle at display refresh rate via TimelineView + TunerDisplayEngine.
/// No SwiftUI .animation() — all smoothing is handled by the spring-damper physics model.
/// When the note decays, the needle holds its last position and fades to 30% opacity
/// so the user can distinguish "in tune" (solid at center) from "note gone" (faded).
struct AnimatedNeedleView: View {
    let displayEngine: TunerDisplayEngine
    let isActive: Bool
    let tuningState: TuningState

    var body: some View {
        TimelineView(.animation) { _ in
            let cents = displayEngine.update(now: CACurrentMediaTime())
            NeedleDisplay(cents: cents, isActive: isActive, tuningState: tuningState)
                .opacity(isActive ? 1.0 : 0.3)
                .animation(.easeOut(duration: 0.8), value: isActive)
        }
    }
}

// MARK: - NeedleDisplay

struct NeedleDisplay: View {

    let cents: Double
    let isActive: Bool
    let tuningState: TuningState

    private var angle: Double {
        // Always driven by the spring-damper's position.
        // When no note is active, the display engine drifts to center via pushSilence().
        (cents / 50.0) * 90.0
    }

    private var needleColor: Color {
        switch tuningState {
        case .noSignal: return DesignSystem.Colors.muted
        case .outOfRange: return DesignSystem.Colors.wrong
        case .approaching: return DesignSystem.Colors.amber
        case .inTune, .settled: return DesignSystem.Colors.correct
        }
    }

    private var inTuneZoneGlow: Bool {
        tuningState == .inTune || tuningState == .settled
    }

    var body: some View {
        ZStack {
            // Dial arc background
            DialArc()
                .stroke(DesignSystem.Colors.border, lineWidth: 7)
                .frame(width: 340, height: 170)

            // In-tune zone (green arc at center)
            DialArc()
                .trim(from: 0.44, to: 0.56)
                .stroke(DesignSystem.Colors.correct.opacity(inTuneZoneGlow ? 1.0 : 0.6),
                        lineWidth: 9)
                .shadow(color: inTuneZoneGlow
                        ? DesignSystem.Colors.correct.opacity(0.5) : .clear,
                        radius: 6)
                .frame(width: 340, height: 170)

            // Tick marks with labels
            DialTicks()
                .frame(width: 340, height: 170)

            // Needle — color reflects tuning state
            Needle(angle: angle, color: needleColor)
                .frame(width: 340, height: 170)

            // Pivot dot — matches needle color
            Circle()
                .fill(needleColor)
                .frame(width: 16, height: 16)
                .offset(y: 85)
        }
        .frame(height: 190)
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
                let isQuarter = i % 25 == 0
                let len: CGFloat = isMajor ? 18 : (isQuarter ? 14 : 10)
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

            // Tick labels at -50, -25, 0, +25, +50
            let labels: [(Int, String)] = [
                (-50, "-50"), (-25, "-25"), (0, "0"), (25, "+25"), (50, "+50")
            ]
            for (cents, label) in labels {
                let angleDeg = 180.0 + Double(cents + 50) / 100.0 * 180.0
                let rad = angleDeg * .pi / 180
                let labelR = r - 28 // Position labels inside the arc
                let pos = CGPoint(x: centre.x + labelR * cos(rad),
                                  y: centre.y + labelR * sin(rad))

                let color = cents == 0 ? DesignSystem.Colors.correct : DesignSystem.Colors.text2
                let resolved = ctx.resolve(
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(color)
                )
                ctx.draw(resolved, at: pos, anchor: .center)
            }
        }
    }
}

struct Needle: View {
    let angle: Double
    let color: Color

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
            ctx.stroke(path, with: .color(color), lineWidth: 3.5)
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
            Text("-50¢").font(DesignSystem.Typography.bodyLabel).foregroundStyle(DesignSystem.Colors.text)
            Spacer()
            Text("0").font(DesignSystem.Typography.bodyLabel).foregroundStyle(DesignSystem.Colors.correct)
            Spacer()
            Text("+50¢").font(DesignSystem.Typography.bodyLabel).foregroundStyle(DesignSystem.Colors.text)
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
                        DesignSystem.Colors.correct
                            .frame(width: greenEnd)
                    }
                    if yellowEnd > 0 {
                        DesignSystem.Colors.honey
                            .frame(width: yellowEnd)
                    }
                    if redEnd > 0 {
                        DesignSystem.Colors.wrong
                            .frame(width: redEnd)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Labels
                if level < 0.05 {
                    Text("Audio Level")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else if level > 0.95 {
                    Text("CLIP")
                        .font(DesignSystem.Typography.smallLabel)
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
