import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var token        = ""
    @State private var databaseId   = ""
    @State private var saved        = false
    @State private var isTesting    = false
    @State private var testResult: String? = nil
    @State private var testSuccess  = false
    @State private var widgetAdded   = false
    @State private var widgetChecked = false

    var body: some View {
        Form {
            Section("Notion Credentials") {
                TextField("Integration secret (secret_…)", text: $token)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Database ID (32-char hex)", text: $databaseId)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Button("Save to Keychain") {
                KeychainHelper.save(key: KeychainHelper.notionTokenKey, value: token)
                KeychainHelper.save(key: KeychainHelper.databaseIdKey,  value: databaseId)
                saved = true
                testResult = nil
            }
            .disabled(token.isEmpty || databaseId.isEmpty)

            if saved { Text("Saved ✓").foregroundStyle(.green) }

            Section("Test Connection") {
                Button(action: runTest) {
                    HStack {
                        Text("Fetch from Notion")
                        if isTesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting)

                if let result = testResult {
                    Text(result)
                        .foregroundStyle(testSuccess ? .green : .red)
                        .font(.footnote)
                }
            }

            Section("Add Widget") {
                if widgetAdded {
                    Label("Widget is active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Follow these steps to add the Finance widget to your Home Screen:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(steps, id: \.number) { step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(step.number)")
                                    .font(.caption.bold())
                                    .frame(width: 22, height: 22)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                                Text(step.instruction)
                                    .font(.subheadline)
                            }
                        }

                        Button("Check if widget was added") {
                            checkWidgetStatus()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)

                        if widgetChecked {
                            Text("Widget not found on Home Screen yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Hodl Setup")
        .onAppear { checkWidgetStatus() }
    }

    // MARK: - Widget steps

    private struct Step { let number: Int; let instruction: String }

    private let steps: [Step] = [
        Step(number: 1, instruction: "Go to your Home Screen"),
        Step(number: 2, instruction: "Long-press any empty area until icons jiggle"),
        Step(number: 3, instruction: "Tap the + button in the top-left corner"),
        Step(number: 4, instruction: "Search for Hodl"),
        Step(number: 5, instruction: "Choose a size and tap Add Widget"),
    ]

    // MARK: - Helpers

    private func checkWidgetStatus() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            DispatchQueue.main.async {
                if case .success(let widgets) = result {
                    widgetAdded   = widgets.contains { $0.kind == "FinanceWidget" }
                    widgetChecked = !widgetAdded
                }
            }
        }
    }

    private func runTest() {
        isTesting  = true
        testResult = nil
        Task {
            do {
                let summary = try await NotionFinanceService.fetchMonthlySummary(monthlySpendLimit: 0)
                testResult  = """
                ✅ Connected!
                Income:  ₦\(Int(summary.totalIncome))
                Spend:   ₦\(Int(summary.totalSpend))
                Entries fetched successfully.
                """
                testSuccess = true
            } catch {
                testResult  = "❌ \(error.localizedDescription)"
                testSuccess = false
            }
            isTesting = false
        }
    }
}
