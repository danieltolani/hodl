import SwiftUI

struct HomeView: View {
    @State private var summary: FinanceSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                // Month header
                Text(monthHeader)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)

                Spacer().frame(height: 4)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if let summary {
                    let net = summary.totalIncome - summary.totalSpend

                    BalanceCard(
                        label: "Spend balance",
                        amount: summary.totalSpend,
                        subtitle: netSubtitle(net)
                    )
                    BalanceCard(label: "Income", amount: summary.totalIncome)
                    BalanceCard(
                        label: "Net savings",
                        amount: net
                    )
                } else if let msg = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Settings gear — top right, matching Figma position
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.black)
                    .padding(20)
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: { Task { await loadSummary() } }) {
            NavigationStack {
                ContentView()
            }
        }
        .task { await loadSummary() }
        .refreshable { await loadSummary() }
    }

    // MARK: - Helpers

    private var monthHeader: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    private func netSubtitle(_ net: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let str = formatter.string(from: NSNumber(value: abs(net))) ?? "0"
        return net >= 0 ? "N\(str) ahead" : "N\(str) in the red"
    }

    private func loadSummary() async {
        isLoading = true
        errorMessage = nil
        do {
            summary = try await NotionFinanceService.fetchMonthlySummary(monthlySpendLimit: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
