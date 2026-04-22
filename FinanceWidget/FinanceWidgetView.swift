// FinanceWidgetView.swift
// SwiftUI widget UI — adapts layout for systemSmall and systemMedium.

import SwiftUI
import WidgetKit

// MARK: - Root view (dispatches by family)

struct FinanceWidgetView: View {

    let entry: FinanceEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            default:            SmallWidgetView(entry: entry)
            }
        }
        .widgetBackground()
    }
}

// MARK: - systemSmall
// Three stacked rows in a compact vertical list.

private struct SmallWidgetView: View {

    let entry: FinanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text("Finance")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            Spacer(minLength: 0)

            // Rows
            VStack(alignment: .leading, spacing: 5) {
                FinanceRow(icon: "💰", label: nil,
                           amount: entry.summary.totalIncome,
                           color: .green)

                FinanceRow(icon: "💸", label: nil,
                           amount: entry.summary.totalSpend,
                           color: .red)

                FinanceRow(
                    icon:   entry.summary.isOverBudget ? "⚠️" : "📉",
                    label:  nil,
                    amount: abs(entry.summary.remaining),
                    color:  remainingColor(for: entry.summary),
                    prefix: entry.summary.isOverBudget ? "-" : nil
                )
            }

            Spacer(minLength: 4)

            // Stale badge
            if entry.isStale {
                StaleIndicator()
            }
        }
        .padding(12)
    }
}

// MARK: - systemMedium
// Left column: icons + labels.  Right column: values, right-aligned.

private struct MediumWidgetView: View {

    let entry: FinanceEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // ── Left: labels ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Text("Monthly Finance")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 10)

                VStack(alignment: .leading, spacing: 8) {
                    LabelRow(icon: "💰", text: "Income",  color: .green)
                    LabelRow(icon: "💸", text: "Spend",   color: .red)
                    LabelRow(
                        icon:  entry.summary.isOverBudget ? "⚠️" : "📉",
                        text:  entry.summary.isOverBudget ? "Over budget" : "Remaining",
                        color: remainingColor(for: entry.summary)
                    )
                }

                Spacer(minLength: 8)

                if entry.isStale {
                    StaleIndicator()
                }
            }

            Spacer()

            // ── Right: values ─────────────────────────────────────────────
            VStack(alignment: .trailing, spacing: 0) {

                // Spacer aligns with the header text height
                Text(" ").font(.caption).hidden()

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    AmountLabel(
                        amount: entry.summary.totalIncome,
                        color:  .green
                    )
                    AmountLabel(
                        amount: entry.summary.totalSpend,
                        color:  .red
                    )
                    AmountLabel(
                        amount: abs(entry.summary.remaining),
                        color:  remainingColor(for: entry.summary),
                        prefix: entry.summary.isOverBudget ? "-" : nil
                    )
                }

                Spacer(minLength: 8)

                // Last-updated timestamp
                Text(entry.summary.lastUpdated, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }
}

// MARK: - Reusable sub-views

/// Single data row used inside systemSmall (icon + formatted amount).
private struct FinanceRow: View {
    let icon:   String
    let label:  String?
    let amount: Double
    let color:  Color
    var prefix: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.subheadline)
            if let lbl = label {
                Text(lbl)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let pfx = prefix {
                Text(pfx)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            Text(ngnFormatted(amount))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Label column cell (icon + text) for systemMedium.
private struct LabelRow: View {
    let icon:  String
    let text:  String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.subheadline)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

/// Value column cell for systemMedium.
private struct AmountLabel: View {
    let amount: Double
    let color:  Color
    var prefix: String? = nil

    var body: some View {
        HStack(spacing: 2) {
            if let pfx = prefix {
                Text(pfx)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            Text(ngnFormatted(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Small orange banner shown when cached (stale) data is being displayed.
private struct StaleIndicator: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Cached data")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.orange)
    }
}

// MARK: - Helpers

private func remainingColor(for summary: FinanceSummary) -> Color {
    summary.isOverBudget ? .orange : .blue
}

/// Formats a Double as ₦1,234 (no decimals, NGN currency code).
private func ngnFormatted(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle           = .currency
    formatter.currencyCode          = "NGN"
    formatter.currencySymbol        = "₦"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "₦0"
}

// MARK: - Cross-platform background shim
// containerBackground(for:) requires iOS 17 / macOS 14.
// Below that, we fall back to a plain .background() modifier.

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            containerBackground(.background, for: .widget)
        } else {
            padding()
                .background(adaptiveBackground)
        }
    }
}

// Platform-appropriate opaque background colour.
private var adaptiveBackground: Color {
    #if os(iOS)
    Color(uiColor: .systemBackground)
    #else
    Color(nsColor: .windowBackgroundColor)
    #endif
}

// MARK: - Previews

#if DEBUG
struct FinanceWidgetView_Previews: PreviewProvider {

    static var normal: FinanceEntry {
        FinanceEntry(date: Date(), summary: .placeholder, isStale: false, errorMessage: nil)
    }

    static var stale: FinanceEntry {
        FinanceEntry(date: Date(), summary: .placeholder, isStale: true, errorMessage: "Network unavailable")
    }

    static var overBudget: FinanceEntry {
        FinanceEntry(
            date: Date(),
            summary: FinanceSummary(totalIncome: 400_000, totalSpend: 280_000, monthlySpendLimit: 250_000),
            isStale: false,
            errorMessage: nil
        )
    }

    static var previews: some View {
        Group {
            FinanceWidgetView(entry: normal)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small – normal")

            FinanceWidgetView(entry: normal)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – normal")

            FinanceWidgetView(entry: stale)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – stale")

            FinanceWidgetView(entry: overBudget)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – over budget")
        }
    }
}
#endif
