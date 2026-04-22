// NotionFinanceService.swift
// Networking layer for the Notion REST API.
// Uses only Foundation (URLSession) — no third-party dependencies.
//
// What this service does:
//   • Reads all transactions for the current calendar month from your
//     "{MONTH} FIGURES (NGN)" Notion database.
//   • Sums them into income and spend totals.
//   • The monthly spend limit is provided by the caller (from the widget's
//     AppIntent configuration) — Notion is not involved in that value.
//
// Notion property name assumptions (edit the constants below if yours differ):
//   • "Amount"  — Number    — the transaction value in NGN
//   • "Type"    — Select or Multi-select — must contain "#income" or "#expense"
//   • "Date"    — Date      — when the transaction occurred

import Foundation

// MARK: - Error types

public enum NotionError: Error, LocalizedError {
    case missingCredentials
    case unauthorized
    case rateLimited
    case networkFailure(Error)
    case decodingFailure(String)
    case invalidResponse(Int)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Notion API token or database ID not found in Keychain."
        case .unauthorized:
            return "Notion returned 401 – check your integration token."
        case .rateLimited:
            return "Notion returned 429 – rate limited; will retry on next refresh."
        case .networkFailure(let err):
            return "Network error: \(err.localizedDescription)"
        case .decodingFailure(let detail):
            return "Decoding failure: \(detail)"
        case .invalidResponse(let code):
            return "Unexpected HTTP \(code) from Notion API."
        }
    }
}

// MARK: - Service

public struct NotionFinanceService {

    private static let baseURL       = "https://api.notion.com/v1"
    private static let notionVersion = "2022-06-28"

    // ── Notion column names ───────────────────────────────────────────────────
    // Matches your database: separate number columns for income and expenses.
    private static let incomeProperty   = "Income"
    private static let expensesProperty = "Expenses"

    // MARK: - Public API

    /// Fetches all rows in the database and returns a `FinanceSummary`.
    /// No date filter is applied — each month uses its own dedicated database.
    ///
    /// - Parameter monthlySpendLimit: The user-configured limit (passed in from
    ///   `FinanceWidgetIntent.spendLimit`). Notion is not queried for this value.
    public static func fetchMonthlySummary(monthlySpendLimit: Double) async throws -> FinanceSummary {

        // 1. Load API credentials from Keychain.
        guard
            let token      = KeychainHelper.load(key: KeychainHelper.notionTokenKey),
            let databaseId = KeychainHelper.load(key: KeychainHelper.databaseIdKey)
        else {
            throw NotionError.missingCredentials
        }

        // 2. Fetch all rows — no date filter needed since each month has its
        //    own dedicated database (APRIL FIGURES, MAY FIGURES, etc.).
        let allResults = try await fetchAllPages(
            databaseId: databaseId,
            token:      token
        )

        // 4. Tally income and spend by reading the two dedicated number columns.
        var totalIncome: Double = 0
        var totalSpend:  Double = 0

        for result in allResults {
            guard let properties = result["properties"] as? [String: Any] else { continue }
            totalIncome += extractNumber(from: properties, key: incomeProperty)   ?? 0
            totalSpend  += extractNumber(from: properties, key: expensesProperty) ?? 0
        }

        return FinanceSummary(
            totalIncome:       totalIncome,
            totalSpend:        totalSpend,
            monthlySpendLimit: monthlySpendLimit,
            lastUpdated:       Date()
        )
    }

    // MARK: - Pagination

    /// Loops through `has_more` / `next_cursor` until all results are collected.
    private static func fetchAllPages(
        databaseId: String,
        token:      String
    ) async throws -> [[String: Any]] {

        var allResults: [[String: Any]] = []
        var nextCursor: String?         = nil
        var hasMore                     = true

        while hasMore {
            let (pageResults, cursor, more) = try await queryOnePage(
                databaseId: databaseId,
                token:      token,
                cursor:     nextCursor
            )
            allResults.append(contentsOf: pageResults)
            nextCursor = cursor
            hasMore    = more
        }

        return allResults
    }

    // MARK: - Single page query

    private static func queryOnePage(
        databaseId: String,
        token:      String,
        cursor:     String?
    ) async throws -> (results: [[String: Any]], nextCursor: String?, hasMore: Bool) {

        guard let url = URL(string: "\(baseURL)/databases/\(databaseId)/query") else {
            throw NotionError.decodingFailure("Could not build URL for database ID: \(databaseId)")
        }

        var request             = URLRequest(url: url)
        request.httpMethod      = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(notionVersion,      forHTTPHeaderField: "Notion-Version")

        var body: [String: Any] = ["page_size": 100]
        if let cursor = cursor {
            body["start_cursor"] = cursor
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw NotionError.decodingFailure("Failed to serialise query body: \(error)")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NotionError.networkFailure(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NotionError.decodingFailure("Non-HTTP response received")
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw NotionError.unauthorized
        case 429:
            throw NotionError.rateLimited
        default:
            throw NotionError.invalidResponse(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            throw NotionError.decodingFailure("Top-level JSON parse failed. Body: \(preview)")
        }

        let results    = json["results"]     as? [[String: Any]] ?? []
        let hasMore    = json["has_more"]    as? Bool            ?? false
        let nextCursor = json["next_cursor"] as? String

        return (results, nextCursor, hasMore)
    }

    // MARK: - Property extractors

    private static func extractNumber(from properties: [String: Any], key: String) -> Double? {
        guard let prop = properties[key] as? [String: Any] else { return nil }
        return prop["number"] as? Double
    }

    /// Handles both `select` (single value) and `multi_select` (array).
    /// Returns a comma-joined string so callers can use a simple `contains` check.
    private static func extractSelectValue(from properties: [String: Any], key: String) -> String? {
        guard let prop = properties[key] as? [String: Any] else { return nil }

        if let select = prop["select"] as? [String: Any],
           let name   = select["name"] as? String {
            return name
        }

        if let multiSelect = prop["multi_select"] as? [[String: Any]] {
            let names = multiSelect.compactMap { $0["name"] as? String }
            return names.isEmpty ? nil : names.joined(separator: ",")
        }

        return nil
    }

}
