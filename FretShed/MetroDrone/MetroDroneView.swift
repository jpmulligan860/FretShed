// MetroDroneView.swift
// FretShed — MetroDrone Feature
//
// Combined metronome + drone practice tool.
// Appears as the 5th tab in the main TabView.

import SwiftUI

struct MetroDroneView: View {

    @State private var vm = MetroDroneViewModel()
    @State private var showSpeedTrainer = false

    @State private var showTempoInfo = false
    @State private var showTimeSignatureInfo = false
    @State private var showSpeedTrainerInfo = false
    @State private var showDroneInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    bpmSection
                    beatIndicators
                    timeSignatureAndAccents
                    playButtons
                    speedTrainerSection
                    droneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear { vm.onDisappear() }
            .sheet(isPresented: $showTempoInfo) {
                MetroDroneInfoSheet(
                    title: "Tempo",
                    items: [
                        ("BPM", "Beats per minute. Tap the Tap button rhythmically to set the tempo."),
                        ("BPM Slider", "Drag to set tempo from 20 to 300 BPM."),
                        ("-1 / +1", "Fine-tune the tempo by one BPM.")
                    ]
                )
            }
            .sheet(isPresented: $showTimeSignatureInfo) {
                MetroDroneInfoSheet(
                    title: "Time Signature & Accents",
                    items: [
                        ("Time Signature", "Number of beats per measure (2/4, 3/4, 4/4, 5/4, 6/8, 7/8)."),
                        ("Note Division", "Subdivision of each beat: quarter, eighth, triplet, or sixteenth notes."),
                        ("Beat Accents", "Tap each beat circle to cycle through normal, accent, and mute."),
                        ("Metronome Volume", "Volume level for the metronome click.")
                    ]
                )
            }
            .sheet(isPresented: $showSpeedTrainerInfo) {
                MetroDroneInfoSheet(
                    title: "Speed Trainer",
                    items: [
                        ("Start BPM", "Beginning tempo for the speed trainer."),
                        ("End BPM", "Target tempo the trainer builds up to."),
                        ("Increment", "BPM increase at each step."),
                        ("Bars per Step", "How many measures to play at each tempo before increasing."),
                        ("Reps per Step", "Number of times to repeat each tempo step."),
                        ("At End", "What happens when the target BPM is reached: stop or loop back."),
                        ("Count In", "Number of count-in bars before the trainer starts (quarter notes only).")
                    ]
                )
            }
            .sheet(isPresented: $showDroneInfo) {
                MetroDroneInfoSheet(
                    title: "Drone Settings",
                    items: [
                        ("Key", "Root note of the drone tone."),
                        ("Octave", "Pitch register of the drone (2nd through 4th octave)."),
                        ("Voicing", "Harmonic content: Root only, Root + 5th (power chord), or Root + 3rd + 5th (triad)."),
                        ("Sound", "Tone character: Sine (pure), Sawtooth (bright), or Pad (warm)."),
                        ("Drone Volume", "Volume level for the drone tone.")
                    ]
                )
            }
        }
    }

    // MARK: - BPM Section

    private var bpmSection: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("Tempo")
                    .font(.headline)
                infoButton { showTempoInfo = true }
                Spacer()
            }

            // Large BPM display
            Text("\(Int(vm.bpm))")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("BPM")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Slider
            Slider(value: $vm.bpm, in: 20...300, step: 1)
                .tint(DesignSystem.Colors.cherry)

            // -1 / Tap / +1 buttons
            HStack(spacing: 16) {
                Button {
                    vm.bpm = max(20, vm.bpm - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Button(action: vm.tapTempo) {
                    Text("Tap")
                        .font(.headline)
                        .frame(width: 80, height: 44)
                        .background(DesignSystem.Colors.cherry.opacity(0.15), in: Capsule())
                }

                Button {
                    vm.bpm = min(300, vm.bpm + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    // MARK: - Beat Indicators

    private var beatIndicators: some View {
        VStack(spacing: 6) {
            if vm.isCountingIn {
                Text("Count In — \(vm.countInBarsRemaining)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            HStack(spacing: 8) {
                ForEach(Array(vm.accents.enumerated()), id: \.offset) { index, accent in
                    let isCurrent = vm.isMetronomePlaying && vm.currentBeat == index
                    let dotColor = vm.isCountingIn ? Color.orange : accentColor(accent)

                    Circle()
                        .fill(isCurrent ? dotColor : dotColor.opacity(0.2))
                        .frame(width: beatDotSize, height: beatDotSize)
                        .overlay(
                            Circle()
                                .strokeBorder(dotColor.opacity(0.5), lineWidth: 1.5)
                        )
                        .scaleEffect(isCurrent ? 1.25 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: vm.currentBeat)
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.15), value: vm.isCountingIn)
    }

    private var beatDotSize: CGFloat {
        vm.timeSignature.beats <= 4 ? 28 : (vm.timeSignature.beats <= 6 ? 22 : 18)
    }

    private func accentColor(_ accent: BeatAccent) -> Color {
        switch accent {
        case .accent: return DesignSystem.Colors.amber
        case .normal: return DesignSystem.Colors.cherry
        case .muted:  return .gray
        }
    }

    // MARK: - Time Signature & Accents

    private var timeSignatureAndAccents: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("Time Signature & Accents")
                    .font(.headline)
                infoButton { showTimeSignatureInfo = true }
                Spacer()
            }

            // Time signature picker
            HStack {
                Text("Time Signature")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Menu {
                    ForEach(TimeSignature.common, id: \.self) { ts in
                        Button(ts.label) {
                            vm.setTimeSignature(ts)
                        }
                    }
                } label: {
                    Text(vm.timeSignature.label)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }

            // Note Division
            VStack(alignment: .leading, spacing: 6) {
                Text("Note Division")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    ForEach(NoteSubdivision.allCases, id: \.self) { div in
                        Button {
                            vm.setSubdivision(div)
                        } label: {
                            Text(div.label)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .foregroundStyle(vm.subdivision == div ? .white : .primary)
                                .background(
                                    vm.subdivision == div
                                        ? DesignSystem.Colors.cherry
                                        : Color.gray.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Beat accents
            HStack {
                Text("Beat Accents")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(Array(vm.accents.enumerated()), id: \.offset) { index, accent in
                    Button { vm.cycleAccent(at: index) } label: {
                        accentLabel(accent)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(accentButtonBackground(accent), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Metronome volume
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $vm.metronomeVolume, in: 0...1)
                    .tint(DesignSystem.Colors.cherry)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    @ViewBuilder
    private func accentLabel(_ accent: BeatAccent) -> some View {
        switch accent {
        case .accent:
            Text("A")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        case .normal:
            Text("N")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        case .muted:
            Text("-")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func accentButtonBackground(_ accent: BeatAccent) -> Color {
        switch accent {
        case .accent: return DesignSystem.Colors.amber
        case .normal: return DesignSystem.Colors.cherry
        case .muted:  return .gray.opacity(0.3)
        }
    }

    // MARK: - Play Buttons

    private var playButtons: some View {
        Button(action: vm.toggleMetronome) {
            Label(
                vm.isMetronomePlaying ? "Stop Metronome" : "Start Metronome",
                systemImage: vm.isMetronomePlaying ? "stop.fill" : "play.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(vm.isMetronomePlaying ? DesignSystem.Colors.wrong : DesignSystem.Colors.cherry, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Speed Trainer

    private var speedTrainerSection: some View {
        DisclosureGroup(isExpanded: $showSpeedTrainer) {
            VStack(spacing: 16) {
                // Start / End BPM
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "\(Int(vm.speedTrainerStartBPM))",
                            value: $vm.speedTrainerStartBPM,
                            in: 20...299,
                            step: 1
                        )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "\(Int(vm.speedTrainerEndBPM))",
                            value: $vm.speedTrainerEndBPM,
                            in: 21...300,
                            step: 1
                        )
                    }
                }

                // Increment
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Increment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "+\(Int(vm.speedTrainerIncrement)) BPM",
                            value: $vm.speedTrainerIncrement,
                            in: 1...50,
                            step: 1
                        )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bars per Step")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "\(vm.speedTrainerBarsPerStep)",
                            value: $vm.speedTrainerBarsPerStep,
                            in: 1...32,
                            step: 1
                        )
                    }
                }

                // Reps per step
                Stepper(
                    "Reps per step: \(vm.speedTrainerRepsPerStep)",
                    value: $vm.speedTrainerRepsPerStep,
                    in: 1...16,
                    step: 1
                )

                // End mode toggle
                Picker("At End", selection: $vm.speedTrainerEndMode) {
                    ForEach(SpeedTrainerEndMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Count-in bars (before speed trainer starts)
                HStack {
                    Text("Count In")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Stepper(
                        vm.countInBars == 0 ? "Off" : "\(vm.countInBars) bar\(vm.countInBars == 1 ? "" : "s")",
                        value: $vm.countInBars,
                        in: 0...4,
                        step: 1
                    )
                    .frame(maxWidth: 180)
                }

                // Speed trainer status
                if vm.isSpeedTrainerActive {
                    Text("Current: \(Int(vm.currentTrainerBPM)) BPM")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                // Start / Stop trainer
                Button(action: vm.toggleSpeedTrainer) {
                    Label(
                        vm.isSpeedTrainerActive ? "Stop Trainer" : "Start Trainer",
                        systemImage: vm.isSpeedTrainerActive ? "stop.fill" : "hare.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(.white)
                    .background(vm.isSpeedTrainerActive ? DesignSystem.Colors.wrong : DesignSystem.Colors.amber, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Speed Trainer")
                infoButton { showSpeedTrainerInfo = true }
            }
        }
        .padding()
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    // MARK: - Drone Section

    private var droneSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Drone Settings")
                    .font(.headline)
                infoButton { showDroneInfo = true }
                Spacer()
            }

            // Key picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Key")
                    .font(.subheadline.weight(.medium))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(MusicalNote.allCases) { note in
                        Button {
                            vm.droneKey = note
                        } label: {
                            Text(note.sharpName)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .foregroundStyle(vm.droneKey == note ? .white : .primary)
                                .background(
                                    vm.droneKey == note ? DesignSystem.Colors.amber : DesignSystem.Colors.surface2,
                                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Octave picker
            HStack {
                Text("Octave")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Picker("Octave", selection: $vm.droneOctave) {
                    ForEach(2...4, id: \.self) { oct in
                        Text("\(oct)").tag(oct)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }

            // Voicing picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Voicing")
                    .font(.subheadline.weight(.medium))

                Picker("Voicing", selection: $vm.droneVoicing) {
                    ForEach(DroneVoicing.allCases, id: \.self) { voicing in
                        Text(voicing.label).tag(voicing)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Sound picker
            HStack {
                Text("Sound")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Picker("Sound", selection: $vm.droneSound) {
                    ForEach(DroneSound.allCases, id: \.self) { sound in
                        Text(sound.label).tag(sound)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

            // Drone volume
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $vm.droneVolume, in: 0...1)
                    .tint(DesignSystem.Colors.amber)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Drone play button
            Button(action: vm.toggleDrone) {
                Label(
                    vm.isDronePlaying ? "Stop Drone" : "Start Drone",
                    systemImage: vm.isDronePlaying ? "stop.fill" : "play.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(vm.isDronePlaying ? DesignSystem.Colors.wrong : DesignSystem.Colors.amber,
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    // MARK: - Info Button

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - MetroDroneInfoSheet

private struct MetroDroneInfoSheet: View {

    let title: String
    let items: [(String, String)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.0) { label, description in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    MetroDroneView()
}
