//
//  ContentView.swift
//  TermWise
//
//  Created by Dorian Bansoodeb on 2026-05-05.
//

import SwiftUI

struct ContentView: View {
    private let monthlyBalance: Double = 1240
    private let plannedSpend: Double = 1480
    private let actualSpend: Double = 1125
    private let categoryProgress: [(name: String, spent: Double, budget: Double)] = [
        ("Rent", 900, 900),
        ("Groceries", 180, 280),
        ("Transportation", 85, 120),
        ("Eating Out", 96, 140)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TermWise")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Plan vs. Reality")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    metricCard(title: "Balance", value: monthlyBalance, color: .blue)
                    metricCard(title: "Actual Spend", value: actualSpend, color: .orange)
                }

                HStack(spacing: 12) {
                    metricCard(title: "Planned Spend", value: plannedSpend, color: .indigo)
                    metricCard(title: "Delta", value: plannedSpend - actualSpend, color: .green)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Awareness")
                        .font(.headline)
                    infoChip(text: "You have used 69% of your eating-out budget with 19 days left.")
                    infoChip(text: "At this pace, you are under budget by $355 this month.")
                    infoChip(text: "A +$100 gift improves your projected tuition balance.")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Category Progress")
                        .font(.headline)
                    ForEach(categoryProgress, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("$\(Int(item.spent)) / $\(Int(item.budget))")
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: item.spent, total: item.budget)
                                .tint(item.spent > item.budget ? .red : .blue)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func metricCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
}
