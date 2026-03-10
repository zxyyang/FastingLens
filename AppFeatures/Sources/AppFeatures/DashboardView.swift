import SwiftUI

public struct DashboardView: View {
    private let card: DashboardCardModel

    public init(card: DashboardCardModel) {
        self.card = card
    }

    public var body: some View {
        ZStack {
            FastingLensTheme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("断食镜")
                        .font(.fastingLabel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FastingLensTheme.ink.opacity(0.08), in: Capsule())

                    Text(card.phaseTitle)
                        .font(.fastingHero)
                        .foregroundStyle(FastingLensTheme.ink)

                    Text(card.accentLabel)
                        .font(.fastingLabel)
                        .tracking(1.6)
                        .foregroundStyle(FastingLensTheme.ink.opacity(0.6))
                }

                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(FastingLensTheme.fog, lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: card.progressValue)
                            .stroke(
                                AngularGradient(
                                    colors: [FastingLensTheme.sage, FastingLensTheme.citron, FastingLensTheme.tomato],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("剩余")
                                .font(.fastingLabel)
                                .foregroundStyle(FastingLensTheme.ink.opacity(0.55))
                            Text(card.remainingText)
                                .font(.fastingDigits)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(FastingLensTheme.ink)
                        }
                    }
                    .frame(width: 188, height: 188)

                    VStack(alignment: .leading, spacing: 14) {
                        metricBlock(title: "今日热量", value: card.caloriesText)
                        metricBlock(title: "识别流程", value: "拍照 -> 识别 -> 确认")
                        metricBlock(title: "手表状态", value: "表盘组件已就绪")
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    actionButton("识别餐食", fill: FastingLensTheme.ink, foreground: FastingLensTheme.paper)
                    actionButton("调整模型", fill: FastingLensTheme.citron, foreground: FastingLensTheme.ink)
                }
            }
            .padding(28)
        }
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.fastingLabel)
                .foregroundStyle(FastingLensTheme.ink.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(FastingLensTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FastingLensTheme.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private func actionButton(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    DashboardView(card: DashboardViewModel.makeCard(snapshot: SharedSnapshotStore.initialSnapshot()))
}
