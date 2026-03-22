// OnboardingView.swift
// FretShed — App Layer
//
// First-launch onboarding: 2 screens.
//   0 — Welcome
//   1 — Baseline selection ("Where are you?")
//
// Microphone permission is deferred to calibration (when the mic is first needed).
// Notification permission is deferred to a future release.
//
// Wired via FretShedApp: shown as fullScreenCover when !hasCompletedOnboarding.
// Setting hasCompletedOnboarding = true (via @AppStorage) dismisses the cover.

import SwiftUI
import TelemetryDeck

struct OnboardingView: View {

    @AppStorage(LocalUserPreferences.Key.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false

    @State private var currentPage = 0
    @State private var selectedBaseline: BaselineLevel?

    private let pageCount = 2

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                baselinePage.tag(1)
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

            // App icon
            Image("AppIconDisplay")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 4)
                .padding(.bottom, DesignSystem.Spacing.lg)

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

    // MARK: - Screen 1: Baseline selection

    private var baselinePage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 90)

            Text("Where are you?")
                .font(DesignSystem.Typography.subDisplay)
                .foregroundStyle(DesignSystem.Colors.text)
                .padding(.bottom, DesignSystem.Spacing.xs)

            Text("Pick the one that sounds most like you.")
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
                Image(systemName: baselineIcon(level))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(baselineIconColor(level))
                    .frame(width: 28, height: 28)
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

    // MARK: - Baseline Icons

    private func baselineIcon(_ level: BaselineLevel) -> String {
        switch level {
        case .startingFresh:    return "leaf.fill"
        case .chordPlayer:      return "music.note"
        case .openPosition:     return "hand.point.up.left.fill"
        case .lowStringsSolid:  return "waveform"
        case .rustyEverywhere:  return "guitars.fill"
        }
    }

    private func baselineIconColor(_ level: BaselineLevel) -> Color {
        switch level {
        case .startingFresh:    return DesignSystem.Colors.amber
        case .chordPlayer:      return DesignSystem.Colors.cherry
        case .openPosition:     return DesignSystem.Colors.cherry
        case .lowStringsSolid:  return DesignSystem.Colors.amber
        case .rustyEverywhere:  return DesignSystem.Colors.cherry
        }
    }

    // MARK: - Actions

    private func complete() {
        TelemetryDeck.signal(AnalyticsEvent.onboardingCompleted)
        hasCompletedOnboarding = true
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
}
