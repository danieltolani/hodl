import SwiftUI

struct BalanceCard: View {
    let label: String
    let amount: Double
    var subtitle: String? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.039, green: 0.039, blue: 0.039))

            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))

                Text(formatted)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    private var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let abs = formatter.string(from: NSNumber(value: Swift.abs(amount))) ?? "0"
        return amount < 0 ? "-N\(abs)" : "N\(abs)"
    }
}
