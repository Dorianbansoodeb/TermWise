import SwiftUI

struct LandingView: View {
    let onGetStarted: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("TermWise")
                    .font(.system(size: 44, weight: .bold))

                Text("Student Finance & Co-op Planner")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Plan your school terms, co-op income, expenses, and daily spending.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button("Get Started", action: onGetStarted)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Log In", action: onLogIn)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    LandingView(onGetStarted: {}, onLogIn: {})
}
