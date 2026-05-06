import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            ForEach(appState.transactions) { transaction in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.category)
                            .fontWeight(.semibold)
                        Text(transaction.note.isEmpty ? "No note" : transaction.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(transaction.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(signedAmountText(for: transaction))
                        .fontWeight(.bold)
                        .foregroundStyle(transaction.type == .expense ? .red : .green)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Transactions")
    }

    private func signedAmountText(for transaction: TransactionItem) -> String {
        let sign = transaction.type == .expense ? "-" : "+"
        return "\(sign)\(transaction.amount, format: .currency(code: "USD"))"
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
            .environmentObject(AppState())
    }
}
