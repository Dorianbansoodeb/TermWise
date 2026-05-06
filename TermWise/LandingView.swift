import SwiftUI

struct LandingView: View {
    let onGetStarted: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.12), Color(.systemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Text("TermWise")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Student Finance & Co-op Planner")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Plan your term. Track your spending. Stay on budget.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                previewCard
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button("Get Started", action: onGetStarted)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button("Log In", action: onLogIn)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundStyle(.blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Text("Smart nudges")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 90)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan vs Reality")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Friendly insights help you stay on budget through school and co-op.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10),
                    alignment: .leading
                )

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("No setup stress. Start simple and improve as you go.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    LandingView(onGetStarted: {}, onLogIn: {})
}
