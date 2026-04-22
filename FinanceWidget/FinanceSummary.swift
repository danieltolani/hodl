// FinanceSummary.swift
// Shared data model used by both the service layer and the widget view.
// Conforms to Codable so it can be JSON-encoded into UserDefaults as a
// stale-data fallback between successful network fetches.

import Foundation

public struct FinanceSummary: Codable, Equatable {

    public let totalIncome:       Double
    public let totalSpend:        Double
    public let monthlySpendLimit: Double
    public let lastUpdated:       Date

    /// Positive → under budget.  Negative → over budget.
    public var remaining: Double { monthlySpendLimit - totalSpend }

    public var isOverBudget: Bool { remaining < 0 }

    // MARK: - Init

    public init(
        totalIncome:       Double,
        totalSpend:        Double,
        monthlySpendLimit: Double,
        lastUpdated:       Date = Date()
    ) {
        self.totalIncome       = totalIncome
        self.totalSpend        = totalSpend
        self.monthlySpendLimit = monthlySpendLimit
        self.lastUpdated       = lastUpdated
    }

    // MARK: - Static presets

    /// Realistic-looking data shown while the widget is in the placeholder state.
    public static let placeholder = FinanceSummary(
        totalIncome:       420_000,
        totalSpend:        185_000,
        monthlySpendLimit: 250_000
    )

    /// Zero-value summary used when no cache exists and the network is unavailable.
    public static let empty = FinanceSummary(
        totalIncome:       0,
        totalSpend:        0,
        monthlySpendLimit: 0
    )
}
