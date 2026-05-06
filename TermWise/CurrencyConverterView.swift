import SwiftUI

struct CurrencyConverterView: View {
    @EnvironmentObject private var appState: AppState

    @State private var amountString: String = "100"
    @State private var fromCode: String = "USD"
    @State private var toCode: String = "CAD"

    private let supportedCurrencies = ["USD", "CAD", "EUR", "GBP", "JPY", "AUD", "INR", "CNY", "MXN"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                }

                Section("From") {
                    Picker("From", selection: $fromCode) {
                        ForEach(supportedCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section("To") {
                    Picker("To", selection: $toCode) {
                        ForEach(supportedCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                if let amount = Double(amountString) {
                    Section("Result") {
                        let converted = convert(amount: amount, from: fromCode, to: toCode)
                        let rate = exchangeRate(from: fromCode, to: toCode)
                        HStack {
                            Text("\(amount, format: .number) \(fromCode)")
                            Spacer()
                            Text("\(converted, format: .number) \(toCode)")
                                .fontWeight(.semibold)
                        }

                        Text("Exchange rate: 1 \(fromCode) = \(rate, format: .number.precision(.fractionLength(4))) \(toCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Currency Converter")
        }
    }

    private func convert(amount: Double, from: String, to: String) -> Double {
        // Very simple mock conversion just for local planning UI
        // Base unit is USD
        let usdAmount = amount / rate(for: from)
        return usdAmount * rate(for: to)
    }

    private func exchangeRate(from: String, to: String) -> Double {
        rate(for: to) / rate(for: from)
    }

    private func rate(for code: String) -> Double {
        switch code {
        case "USD": return 1
        case "CAD": return 1.35
        case "EUR": return 0.92
        case "GBP": return 0.78
        case "JPY": return 154
        case "AUD": return 1.52
        case "INR": return 83.2
        case "CNY": return 7.24
        case "MXN": return 17.0
        default: return 1
        }
    }
}

#Preview {
    CurrencyConverterView()
        .environmentObject(AppState())
}
