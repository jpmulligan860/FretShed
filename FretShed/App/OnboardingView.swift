// OnboardingView.swift
// FretShed — App Layer
//
// First-launch onboarding: 3 screens.
//   0 — Welcome
//   1 — How it works
//   2 — Mic permission (explain WHY before triggering system prompt)
//
// The audio test screen was removed — the full Audio Calibration flow
// (accessible from the Practice tab's "Do This First" card) provides a
// better first-run audio experience with noise measurement and per-string
// detection testing.
//
// Wired via FretShedApp: shown as fullScreenCover when !hasCompletedOnboarding.
// Setting hasCompletedOnboarding = true (via @AppStorage) dismisses the cover.

import SwiftUI
import AVFoundation

struct OnboardingView: View {

    @AppStorage(LocalUserPreferences.Key.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false

    @State private var currentPage = 0
    @State private var hasRequestedMicPermission = false

    private let pageCount = 3

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                micPermissionPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // ── Top chrome: page dots + skip ────────────────────────
            VStack {
                ZStack {
                    pageIndicator
                        .frame(maxWidth: .infinity)

                    if currentPage > 0 {
                        HStack {
                            Spacer()
                            Button("Skip") { complete() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage
                          ? DesignSystem.Colors.primary
                          : DesignSystem.Colors.surfaceSecondary)
                    .frame(width: i == currentPage ? 20 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Screen 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "guitars.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignSystem.Colors.primary)
                .padding(.bottom, DesignSystem.Spacing.lg)

            Text("Welcome to\nFretShed")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.bottom, DesignSystem.Spacing.sm)

            Text("The guitar trainer that actually\nlistens to you play.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            primaryButton("Get Started") {
                withAnimation { currentPage = 1 }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Screen 1: How it works

    private var howItWorksPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How it works")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .padding(.bottom, DesignSystem.Spacing.xl)

            VStack(spacing: DesignSystem.Spacing.lg) {
                featureRow(
                    icon: "tuningfork",
                    color: DesignSystem.Colors.primary,
                    title: "Flexible Fretboard Trainer:",
                    subtitle: "FretShed listens and instantly identifies if you played the right note."
                )
                featureRow(
                    icon: "slider.horizontal.3",
                    color: .orange,
                    title: "Great Practice Tools",
                    subtitle: "FretShed's Tuner, Metronome, Speed Trainer and Drones, keep practice interesting."
                )
                featureRow(
                    icon: "brain",
                    color: DesignSystem.Colors.secondary,
                    title: "Adaptive learning",
                    subtitle: "FretShed learns the notes you find hardest and helps you overcome your weak spots."
                )
                featureRow(
                    icon: "chart.bar.fill",
                    color: DesignSystem.Colors.info,
                    title: "Track your progress",
                    subtitle: "Tons of stats, a fretboard heatmap and graphs shows your mastery across all areas of the fretboard."
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            primaryButton("Next") {
                withAnimation { currentPage = 2 }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Screen 2: Mic permission

    private var micPermissionPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.primary)
                .padding(.bottom, DesignSystem.Spacing.lg)

            Text("Allow Microphone\nAccess")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.sm)

            Text("FretShed uses your microphone to hear the notes you play — no audio is stored or sent anywhere.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xl)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                permissionBullet(icon: "lock.shield.fill",
                                 text: "Audio never leaves your device")
                permissionBullet(icon: "wifi.slash",
                                 text: "No internet connection required")
                permissionBullet(icon: "gear",
                                 text: "Change this any time in Settings")
            }
            .padding(.horizontal, 40)

            Spacer()

            if hasRequestedMicPermission {
                primaryButton("Let's Go!") {
                    complete()
                }
                .padding(.bottom, 48)
            } else {
                primaryButton("Grant Microphone Access") {
                    requestMicPermission()
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Reusable components

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primary,
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    private func featureRow(icon: String, color: Color,
                            title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionBullet(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Actions

    private func requestMicPermission() {
        hasRequestedMicPermission = true
        Task { @MainActor in
            _ = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
}
