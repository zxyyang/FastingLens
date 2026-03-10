import AppFeatures
import Observation
import SwiftUI

@Observable
final class WatchRuntimeStore {
    let sync = WatchSyncBridge()
    var snapshot = SharedSnapshotStore.loadSnapshot() ?? SharedSnapshotStore.initialSnapshot()
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .fastingLensSnapshotDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let snapshot = notification.object as? WatchSnapshotState else { return }
            self?.snapshot = snapshot
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Watch Home (Display Only)

struct WatchHomeView: View {
    @Environment(WatchRuntimeStore.self) private var store

    private var s: WatchSnapshotState { store.snapshot }
    private var isEating: Bool { s.phase == .eating }

    // Fasting/eating progress: how far through the current phase
    private var phaseProgress: Double {
        let eatingDuration = s.eatingWindowEnd.timeIntervalSince(s.eatingWindowStart)
        guard eatingDuration > 0 else { return 0 }

        let total: TimeInterval
        let elapsed: TimeInterval

        if isEating {
            total = eatingDuration
            elapsed = max(Date.now.timeIntervalSince(s.eatingWindowStart), 0)
        } else {
            total = max(24 * 3600 - eatingDuration, 1)
            let remaining = max(s.phaseEndsAt.timeIntervalSince(.now), 0)
            elapsed = total - remaining
        }

        guard total > 0 else { return 0 }
        return max(0, min(elapsed / total, 1.0))
    }

    // Calorie progress
    private var calProgress: Double {
        Double(s.todayCalories) / Double(max(s.dailyCalorieGoal, 1))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // ── Phase Ring ──
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: phaseProgress)
                        .stroke(
                            isEating
                                ? AngularGradient(colors: [.green.opacity(0.6), .green], center: .center)
                                : AngularGradient(colors: [.blue.opacity(0.6), .blue], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Center content
                    VStack(spacing: 2) {
                        Text(s.phaseEndsAt, style: .timer)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(isEating ? "进食中" : "断食中")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isEating ? .green : .blue)
                    }
                }
                .frame(width: 120, height: 120)

                // ── Status Badge ──
                HStack(spacing: 6) {
                    Circle()
                        .fill(isEating ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(isEating ? "🍽️ 进食窗口" : "🔥 断食中")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isEating ? Color.green : Color.blue).opacity(0.2), in: Capsule())

                // ── Calorie Info ──
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text("还可吃 ")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(s.remainingCalories)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                        Text(" 千卡")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Mini calorie bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(calProgress > 1.0 ? Color.red : Color.orange)
                                .frame(width: geo.size.width * min(calProgress, 1.0))
                        }
                    }
                    .frame(height: 4)
                    .clipShape(Capsule())

                    HStack(spacing: 0) {
                        Text("\(s.todayCalories)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(" / \(s.dailyCalorieGoal) kcal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 8)

                // ── Motivational Text ──
                Text(isEating ? "把握进食窗口" : "保持燃脂节奏")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 8)
        }
    }
}

@main
struct FastingLensWatchRuntimeApp: App {
    @State private var store = WatchRuntimeStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        }
    }
}
