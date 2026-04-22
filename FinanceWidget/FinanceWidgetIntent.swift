// FinanceWidgetIntent.swift
// Declares the configurable parameter that appears when the user long-presses
// the widget and taps "Edit Widget".
//
// Requires: iOS 17.0+ / macOS 14.0+  (AppIntents widget configuration)

import AppIntents
import WidgetKit

struct FinanceWidgetIntent: WidgetConfigurationIntent {

    static var title:       LocalizedStringResource = "Finance Settings"
    static var description  = IntentDescription("Set your monthly spend limit.")

    /// The value the user enters in the widget edit sheet.
    /// Stored and managed by WidgetKit — no Keychain or UserDefaults needed.
    @Parameter(
        title:   "Monthly Spend Limit (₦)",
        description: "Enter the maximum amount you want to spend this month, in Naira.",
        default: 250_000.0,
        inclusiveRange: (0, 100_000_000)
    )
    var spendLimit: Double
}
