// OnboardingView.swift
// FretShed — App Layer
//
// First-launch onboarding: 3 screens.
//   0 — Welcome
//   1 — How it works
//   2 — Baseline selection ("Where are you at?")
//
// Microphone permission is deferred to calibration (when the mic is first needed).
// Notification permission is deferred to a future release.
//
// Wired via FretShedApp: shown as fullScreenCover when !hasCompletedOnboarding.
// Setting hasCompletedOnboarding = true (via @AppStorage) dismisses the cover.

import SwiftUI

struct OnboardingView: View {

    @AppStorage(LocalUserPreferences.Key.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false

    @State private var currentPage = 0
    @State private var selectedBaseline: BaselineLevel?

    private let pageCount = 3

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                baselinePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Top chrome: skip button
            VStack {
                HStack {
                    Spacer()
                    if currentPage > 0 {
                        Button("Skip") { complete() }
                            .font(DesignSystem.Typography.bodyLabel)
                            .foregroundStyle(DesignSystem.Colors.muted)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)

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
                          ? DesignSystem.Colors.cherry
                          : DesignSystem.Colors.surface2)
                    .frame(width: i == currentPage ? 20 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Screen 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("FretShed")
                    .font(DesignSystem.Typography.quizNote)
                    .foregroundStyle(DesignSystem.Gradients.sunburst)

                Text("Finally get your notes right.")
                    .font(DesignSystem.Typography.accentBody)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            onboardingButton("Get Started") {
                withAnimation { currentPage = 1 }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Screen 1: How it works

    private var howItWorksPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 90)

            Text("How it works")
                .font(DesignSystem.Typography.subDisplay)
                .foregroundStyle(DesignSystem.Colors.text)
                .padding(.bottom, DesignSystem.Spacing.lg)

            VStack(spacing: 0) {
                featureRow(
                    icon: "brain",
                    color: DesignSystem.Colors.cherry,
                    title: "Smart Practice",
                    subtitle: "A structured path from your first note to full fretboard fluency, adapted to your pace."
                )

                Divider()
                    .overlay(DesignSystem.Colors.border)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                featureRow(
                    icon: "tuningfork",
                    color: DesignSystem.Colors.amber,
                    title: "Flexible Fretboard Trainer",
                    subtitle: "FretShed listens to your guitar and tells you instantly if you nailed it."
                )

                Divider()
                    .overlay(DesignSystem.Colors.border)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                featureRow(
                    icon: "slider.horizontal.3",
                    color: DesignSystem.Colors.honey,
                    title: "Great Practice Tools",
                    subtitle: "Tuner, Metronome, Speed Trainer, and Drone keep practice interesting."
                )

                Divider()
                    .overlay(DesignSystem.Colors.border)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                featureRow(
                    icon: "chart.bar.fill",
                    color: DesignSystem.Colors.gold,
                    title: "Track Your Progress",
                    subtitle: "Stats, heatmaps and graphs show your mastery across the entire fretboard."
                )
            }
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            onboardingButton("Next") {
                withAnimation { currentPage = 2 }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Screen 2: Baseline selection

    private var baselinePage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 90)

            Text("Where are you?")
                .font(DesignSystem.Typography.subDisplay)
                .foregroundStyle(DesignSystem.Colors.text)
                .padding(.bottom, DesignSystem.Spacing.xs)

            Text("Select the category that best reflects\nyour current fretboard knowledge.")
                .font(DesignSystem.Typography.tagline)
                .foregroundStyle(DesignSystem.Colors.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(BaselineLevel.allCases, id: \.rawValue) { level in
                    baselineOption(level)
                }
            }
            .padding(.horizontal, 24)

            Text("Don't worry about getting it perfect —\nFretShed adapts as you play.")
                .font(DesignSystem.Typography.accentDescription)
                .foregroundStyle(DesignSystem.Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.md)

            Spacer()

            onboardingButton("Let's Go!", disabled: selectedBaseline == nil) {
                selectedBaseline?.save()
                complete()
            }
            .padding(.bottom, 48)
        }
    }

    private func baselineOption(_ level: BaselineLevel) -> some View {
        let isSelected = selectedBaseline == level
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBaseline = level
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(level.emoji)
                    .font(DesignSystem.Typography.screenTitle)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                    Text(level.description)
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.cherry)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected ? DesignSystem.Colors.surface2 : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.border,
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components

    private func onboardingButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    disabled ? AnyShapeStyle(DesignSystem.Colors.surface2)
                             : AnyShapeStyle(DesignSystem.Gradients.primary),
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                )
                .foregroundStyle(disabled ? DesignSystem.Colors.muted : .white)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .padding(.horizontal, 24)
    }

    private func featureRow(icon: String, color: Color,
                            title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                Text(subtitle)
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Actions

    private func complete() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
}
