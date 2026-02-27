import Foundation

/// Apple-required subscription disclosure text for PaywallView.
/// These strings must appear on the paywall screen to pass App Store review.
///
/// References:
/// - App Store Review Guidelines, Section 3.1.2 (Subscriptions)
/// - Schedule 2 of the Apple Developer Program License Agreement
/// - https://developer.apple.com/app-store/subscriptions/
enum SubscriptionLegalText {

    // MARK: - Pricing Details

    /// Monthly subscription price.
    static let monthlyPrice = "$4.99/month"

    /// Annual subscription price.
    static let annualPrice = "$29.99/year"

    /// Lifetime (one-time) purchase price.
    static let lifetimePrice = "$49.99 (one-time)"

    /// Free trial duration.
    static let trialLength = "14 days"

    // MARK: - Required Disclosures

    /// Trial disclosure — must appear before the user taps Subscribe.
    /// States the trial length, that it is free, and the price billed when the trial ends.
    static let trialDisclosure = """
        Start your free \(trialLength) trial. \
        You won't be charged during the trial period. \
        After the trial ends, your subscription will automatically renew \
        and your Apple ID will be charged the selected plan price.
        """

    /// Auto-renewal disclosure — states the subscription renews automatically
    /// until cancelled, and that payment is charged to the Apple ID account.
    static let autoRenewalDisclosure = """
        Subscriptions automatically renew unless canceled at least 24 hours \
        before the end of the current period. Your Apple ID account will be \
        charged for renewal within 24 hours prior to the end of the current \
        period at the cost of the selected plan. \
        Monthly: \(monthlyPrice). Annual: \(annualPrice).
        """

    /// Cancellation instructions — tells users exactly where to cancel.
    static let cancellationInstructions = """
        You can manage or cancel your subscription at any time in your \
        device Settings > [your name] > Subscriptions. \
        Cancellation takes effect at the end of the current billing period.
        """

    /// Full legal footer — combines all required disclosures into a single
    /// block of text suitable for the bottom of the paywall screen.
    static let fullDisclosure = """
        A \(trialLength) free trial is included with your first subscription. \
        After the free trial, the subscription automatically renews at \
        \(monthlyPrice) or \(annualPrice) depending on the selected plan, \
        unless canceled at least 24 hours before the end of the current period. \
        Payment will be charged to your Apple ID account at confirmation of purchase. \
        Your account will be charged for renewal within 24 hours prior to the \
        end of the current period. You can manage or cancel your subscription \
        in your device Settings > [your name] > Subscriptions. \
        Any unused portion of a free trial period will be forfeited when you \
        purchase a subscription. \
        By subscribing, you agree to our Terms of Service and Privacy Policy.
        """

    /// Restore purchases prompt.
    static let restorePurchases = "Already subscribed? Tap Restore Purchases."

    // MARK: - Legal Links

    /// Privacy Policy URL — hosted on the FretShed Carrd site.
    static let privacyPolicyURL = "https://fretshed.carrd.co/privacy"

    /// Terms of Service URL — hosted on the FretShed Carrd site.
    static let termsOfServiceURL = "https://fretshed.carrd.co/terms"
}
