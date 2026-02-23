// QuizPresenterWindow.swift
// FretShed — Presentation Layer
//
// Presents quiz + results in a dedicated UIWindow at windowLevel .alert+1.
// This window sits ABOVE UITabBarController and iOS 26's Liquid Glass
// floating tab bar, guaranteeing that every tap reaches SwiftUI buttons
// regardless of what UIKit touch interceptors exist in the main app window.
//
// Quiz → Results transition: QuizPresenterWindow directly swaps
// UIHostingController.rootView when the quiz completes. This avoids any
// @State wrapper view and its associated SwiftUI observation edge cases.
//
// Usage:
//   QuizPresenterWindow.shared.show(vm: vm, container: container)
//   QuizPresenterWindow.shared.dismiss()

import SwiftUI
import UIKit

// MARK: - QuizPresenterWindow

@MainActor
final class QuizPresenterWindow {

    static let shared = QuizPresenterWindow()
    private init() {}

    private var window: UIWindow?
    private var hostVC: UIHostingController<AnyView>?

    // MARK: - Show

    func show(vm: QuizViewModel, container: AppContainer) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }

        // Dismiss any existing quiz window before showing a new one.
        dismiss()

        let quizContent = AnyView(
            QuizView(vm: vm, onDone: { [weak self] in
                self?.dismiss()
            })
            .modelContainer(container.modelContainer)
            .environment(\.appContainer, container)
        )

        let hc = UIHostingController(rootView: quizContent)
        hc.view.backgroundColor = UIColor.systemGroupedBackground
        self.hostVC = hc

        let win = UIWindow(windowScene: scene)
        win.windowLevel = .alert + 1   // Above iOS 26 Liquid Glass tab bar
        win.rootViewController = hc
        win.makeKeyAndVisible()
        self.window = win
    }

    // MARK: - Results Transition

    /// Swaps the hosted root view from QuizView to SessionSummaryView.
    /// Called directly by the onComplete closure — no @State wrapper needed.
    private func transitionToResults(vm: QuizViewModel, container: AppContainer) {
        let resultsContent = AnyView(
            SessionSummaryView(vm: vm, onDone: { [weak self] in
                self?.dismiss()
            })
            .modelContainer(container.modelContainer)
            .environment(\.appContainer, container)
        )
        hostVC?.rootView = resultsContent
    }

    // MARK: - Dismiss

    func dismiss() {
        window?.isHidden = true
        window?.resignKey()
        window = nil
        hostVC = nil
    }
}
