// FinanceWidget.swift
// WidgetKit entry point — AppIntentTimelineProvider + @main Widget struct.
//
// Requires: iOS 17.0+ / macOS 14.0+  (AppIntentConfiguration)
// The SwiftUI view layer (FinanceWidgetView.swift) remains iOS 16 compatible.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct FinanceEntry: TimelineEntry {
    /// Required by TimelineEntry — the date this snapshot represents.
    let date:         Date
    let summary:      FinanceSummary
    /// True when serving cached data because the last network fetch failed.
    let isStale:      Bool
    /// Non-nil when the last fetch ended with an error.
    let errorMessage: String?
}

// MARK: - Timeline Provider

struct FinanceTimelineProvider: AppIntentTimelineProvider {

    typealias Entry  = FinanceEntry
    typealias Intent = FinanceWidgetIntent

    private static let cacheKey = "cachedFinanceSummary"

    // ── Placeholder ──────────────────────────────────────────────────────────
    // Called synchronously while the widget is first loading.
    func placeholder(in context: Context) -> FinanceEntry {
        FinanceEntry(date: Date(), summary: .placeholder, isStale: false, errorMessage: nil)
    }

    // ── Snapshot ─────────────────────────────────────────────────────────────
    // Called for the widget gallery preview; must return quickly.
    func snapshot(for configuration: FinanceWidgetIntent, in context: Context) async -> FinanceEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        // Return the last cached summary (rebased to the configured limit) or
        // fall back to the placeholder so the gallery always looks populated.
        let summary = loadCached(applyingLimit: configuration.spendLimit) ?? .placeholder
        return FinanceEntry(date: Date(), summary: summary, isStale: false, errorMessage: nil)
    }

    // ── Timeline ─────────────────────────────────────────────────────────────
    // Primary refresh path — fetches live data from Notion.
    func timeline(for configuration: FinanceWidgetIntent, in context: Context) async -> Timeline<FinanceEntry> {

        let refreshDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            // spendLimit comes directly from the widget configuration.
            let summary = try await NotionFinanceService.fetchMonthlySummary(
                monthlySpendLimit: configuration.spendLimit
            )
            cacheSummary(summary)

            let entry    = FinanceEntry(date: Date(), summary: summary, isStale: false, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(refreshDate))

        } catch {
            // On failure: serve the last cached snapshot (rebased to current
            // spend limit) and mark it stale, then retry in 15 min.
            let cached = loadCached(applyingLimit: configuration.spendLimit)
            let entry  = FinanceEntry(
                date:         Date(),
                summary:      cached ?? .empty,
                isStale:      cached != nil,
                errorMessage: error.localizedDescription
            )
            return Timeline(entries: [entry], policy: .after(refreshDate))
        }
    }

    // MARK: - UserDefaults cache

    private func cacheSummary(_ summary: FinanceSummary) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    /// Loads the cached summary and replaces its `monthlySpendLimit` with the
    /// value currently set in the widget configuration, so a limit change takes
    /// effect immediately without waiting for the next network fetch.
    private func loadCached(applyingLimit spendLimit: Double) -> FinanceSummary? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cached = try? decoder.decode(FinanceSummary.self, from: data) else { return nil }

        return FinanceSummary(
            totalIncome:       cached.totalIncome,
            totalSpend:        cached.totalSpend,
            monthlySpendLimit: spendLimit,   // always use the live configured limit
            lastUpdated:       cached.lastUpdated
        )
    }
}

// MARK: - Widget

@main
struct FinanceWidget: Widget {

    let kind = "FinanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind:     kind,
            intent:   FinanceWidgetIntent.self,
            provider: FinanceTimelineProvider()
        ) { entry in
            FinanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Finance Summary")
        .description("Monthly income, spend, and remaining budget — powered by Notion.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
