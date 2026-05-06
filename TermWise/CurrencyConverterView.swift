import SwiftUI

struct CurrencyConverterView: View {
    @EnvironmentObject private var appState: AppState

    @State private var amountString: String = "100"
    @State private var fromCode: String = "USD"
    @State private var toCode: String = "CAD"

    private let supportedCurrencies = ["USD", "CAD", "EUR", "GBP"]

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
                        HStack {
                            Text("\(amount, format: .number) \(fromCode)")
                            Spacer()
                            Text("\(converted, format: .number) \(toCode)")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Currency Converter")
        }
    }

    private func convert(amount: Double, from: String, to: String) -> Double {
        // Very simple mock conversion just for local planning UI
        // Base unit is USD
        func rate(for code: String) -> Double {
            switch code {
            case "USD": return 1
            case "CAD": return 1.35
            case "EUR": return 0.92
            case "GBP": return 0.78
            default: return 1
            }
        }

        let usdAmount = amount / rate(for: from)
        return usdAmount * rate(for: to)
    }
}

#Preview {
    CurrencyConverterView()
        .environmentObject(AppState())
}
