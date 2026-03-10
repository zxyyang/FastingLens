import SwiftUI

public struct WatchStatusView: View {
    private let card: DashboardCardModel

    public init(card: DashboardCardModel) {
        self.card = card
    }

    public var body: some View {
        VStack(spacing: 10) {
            Text(card.phaseTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(card.remainingText)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(FastingLensTheme.citron)

            Text(card.caloriesText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            ProgressView(value: card.progressValue)
                .tint(FastingLensTheme.sage)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FastingLensTheme.ink)
        )
    }
}

#Preview {
    WatchStatusView(card: DashboardViewModel.makeCard(snapshot: SharedSnapshotStore.initialSnapshot()))
}
