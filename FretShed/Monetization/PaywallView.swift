// PaywallView.swift
// FretShed — Monetization Layer
//
// Premium subscription paywall. Presented as a sheet when users tap
// a locked focus mode, string, or fret range.

import SwiftUI
import StoreKit

struct PaywallView: View {

    let entitlementManager: EntitlementManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String = EntitlementManager.annualID
    @State private var isPurchasing = false

    private var selectedProduct: Product? {
        entitlementManager.products.first { $0.id == selectedProductID }
    }

    private var phaseManager: LearningPhaseManager { LearningPhaseManager() }

    private var headline: String {
        switch phaseManager.currentPhase {
        case .foundation:
            if phaseManager.phaseOneCompletedStrings.count >= 6 {
                return "Phase 1 done. Keep the momentum going."
            }
            return "You\u{2019}ve got the low strings. Now finish the fretboard."
        default:
            return "Unlock the full fretboard."
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Headline
                    Text(headline)
                        .font(DesignSystem.Typography.subDisplay)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 48)

                    // Value props
                    valueProps

                    // Pricing cards
                    pricingCards

                    // CTA button
                    ctaButton

                    // Restore + legal
                    restoreAndLegal
                }
                .padding(.bottom, 32)
            }

            // Dismiss button
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Colors.muted)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Value Props

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 12) {
            valuePropRow(icon: "guitars", text: "All 6 strings. Every fret. No limits.")
            valuePropRow(icon: "target", text: "All focus modes for targeted practice")
            valuePropRow(icon: "folder.fill", text: "Multiple saved calibration profiles")
        }
        .padding(20)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func valuePropRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.cherry)
                .frame(width: 24)
            Text(text)
                .font(DesignSystem.Typography.accentDescription)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        VStack(spacing: 10) {
            // Annual — prominent
            if let annual = entitlementManager.products.first(where: { $0.id == EntitlementManager.annualID }) {
                pricingCard(
                    product: annual,
                    label: "Annual",
                    priceLabel: "\(annual.displayPrice) / year",
                    badge: "Best Value",
                    isSelected: selectedProductID == EntitlementManager.annualID
                )
            }

            // Monthly — secondary
            if let monthly = entitlementManager.products.first(where: { $0.id == EntitlementManager.monthlyID }) {
                pricingCard(
                    product: monthly,
                    label: "Monthly",
                    priceLabel: "\(monthly.displayPrice) / month",
                    badge: nil,
                    isSelected: selectedProductID == EntitlementManager.monthlyID
                )
            }

            // Lifetime — single row
            if let lifetime = entitlementManager.products.first(where: { $0.id == EntitlementManager.lifetimeID }) {
                pricingCard(
                    product: lifetime,
                    label: "Lifetime Access",
                    priceLabel: "\(lifetime.displayPrice) \u{2014} one time",
                    badge: nil,
                    isSelected: selectedProductID == EntitlementManager.lifetimeID
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func pricingCard(product: Product, label: String, priceLabel: String,
                             badge: String?, isSelected: Bool) -> some View {
        Button {
            selectedProductID = product.id
        } label: {
            VStack(spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(DesignSystem.Typography.bodyLabel)
                            .foregroundStyle(DesignSystem.Colors.text)
                        Text(priceLabel)
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.cherry)
                    }
                }
                if let badge {
                    Text(badge)
                        .font(DesignSystem.Typography.dataChip)
                        .foregroundStyle(DesignSystem.Colors.amber)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.border,
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            isPurchasing = true
            Task {
                do {
                    try await entitlementManager.purchase(product)
                } catch {
                    // Error surfaced via entitlementManager.purchaseError
                }
                isPurchasing = false
                if entitlementManager.isPremium {
                    dismiss()
                }
            }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(selectedProductID == EntitlementManager.lifetimeID
                         ? "Buy Lifetime Access"
                         : "Try Free for 14 Days")
                }
            }
            .font(DesignSystem.Typography.sectionHeader)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || selectedProduct == nil)
        .padding(.horizontal, 20)
    }

    // MARK: - Restore + Legal

    private var restoreAndLegal: some View {
        VStack(spacing: 12) {
            // Error message
            if let error = entitlementManager.purchaseError {
                Text(error)
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.wrong)
                    .multilineTextAlignment(.center)
            }

            // Restore
            Button {
                Task { await entitlementManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }

            // Legal text
            Text(SubscriptionLegalText.fullDisclosure)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Privacy policy link
            Link("Privacy Policy", destination: URL(string: "https://fretshed.com/privacy")!)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.cherry)
        }
        .padding(.horizontal, 20)
    }
}
