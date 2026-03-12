import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "AppLogo",
            imageIsAsset: true,
            title: "Welcome to\nProbably Productive",
            subtitle: "The habit tracker that believes in you.\nMostly.",
            accent: .green
        ),
        OnboardingPage(
            imageName: "checkmark.circle.fill",
            imageIsAsset: false,
            title: "Build Habits.\nOr Pretend To.",
            subtitle: "Track daily habits, earn XP, and level up.\nOr just open the app and feel good about it.\nWe don't judge.",
            accent: .green
        ),
        OnboardingPage(
            imageName: "mood_great",
            imageIsAsset: true,
            title: "How Are You\nFeeling?",
            subtitle: "Log your mood every day.\nIt's cheaper than therapy\nand takes about 3 seconds.",
            accent: .orange
        ),
        OnboardingPage(
            imageName: "star.fill",
            imageIsAsset: false,
            title: "Every Habit\nEarns XP.",
            subtitle: "Complete habits, gain XP, level up.\nEvery excuse earns nothing.\nYour choice.",
            accent: .yellow
        ),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i])
                        .tag(i)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: currentPage)

            bottomBar
        }
        .ignoresSafeArea(edges: .top)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            if page.imageIsAsset {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: page.imageName == "AppLogo" ? 260 : 160)
                    .padding(.horizontal, page.imageName == "AppLogo" ? 0 : 60)
            } else {
                Image(systemName: page.imageName)
                    .font(.system(size: 80))
                    .foregroundStyle(page.accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: i == currentPage ? 20 : 8, height: 8)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }

            // Button
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
            } else {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Let's go. Probably.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .transition(.opacity)
            }
        }
        .padding(.bottom, 48)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}

struct OnboardingPage {
    let imageName: String
    let imageIsAsset: Bool
    let title: String
    let subtitle: String
    let accent: Color
}
