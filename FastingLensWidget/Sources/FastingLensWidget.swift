import AppFeatures
import SwiftUI
import WidgetKit

private enum W {
    static let flame = Color(red: 0.96, green: 0.37, blue: 0.23)
    static let mint = Color(red: 0.30, green: 0.80, blue: 0.60)
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.13)
    static let sub = Color(red: 0.45, green: 0.47, blue: 0.50)
    static let track = Color(red: 0.92, green: 0.93, blue: 0.94)
    // Match home screen theme colors
    static let blue = Color(.sRGB, red: 0x3B / 255.0, green: 0x82 / 255.0, blue: 0xF6 / 255.0)       // #3B82F6
    static let lightBlue = Color(.sRGB, red: 0x60 / 255.0, green: 0xA5 / 255.0, blue: 0xFA / 255.0)   // #60A5FA
    static let greenMint = Color(.sRGB, red: 0x34 / 255.0, green: 0xD3 / 255.0, blue: 0x99 / 255.0)   // #34D399
}

struct FastingLensWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshotState
}

struct FastingLensWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastingLensWidgetEntry {
        FastingLensWidgetEntry(date: .now, snapshot: SharedSnapshotStore.initialSnapshot())
    }
    func getSnapshot(in context: Context, completion: @escaping (FastingLensWidgetEntry) -> Void) {
        completion(FastingLensWidgetEntry(date: .now, snapshot: SharedSnapshotStore.loadSnapshot() ?? SharedSnapshotStore.initialSnapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FastingLensWidgetEntry>) -> Void) {
        let snap = SharedSnapshotStore.loadSnapshot() ?? SharedSnapshotStore.initialSnapshot()
        let next = min(snap.phaseEndsAt, .now.addingTimeInterval(15 * 60))
        completion(Timeline(entries: [FastingLensWidgetEntry(date: .now, snapshot: snap)], policy: .after(next)))
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    let s: WatchSnapshotState
    private var isEating: Bool { s.phase == .eating }
    private var progress: Double { Double(s.todayCalories) / Double(max(s.dailyCalorieGoal, 1)) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(W.track, lineWidth: 8)
                Circle().trim(from: 0, to: min(progress, 1.0))
                    .stroke(W.flame, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("还可以吃").font(.system(size: 9, weight: .medium)).foregroundStyle(W.sub)
                    Text("\(s.remainingCalories)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(W.flame).minimumScaleFactor(0.5)
                    Text("千卡").font(.system(size: 9, weight: .medium)).foregroundStyle(W.sub)
                }
            }.frame(width: 96, height: 96)

            HStack(spacing: 4) {
                Circle().fill(isEating ? W.mint : W.flame).frame(width: 6, height: 6)
                Text(isEating ? "进食中" : "断食中")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isEating ? W.mint : W.flame)
                Text("·")
                Text(s.phaseEndsAt, style: .timer)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(W.ink)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.white, for: .widget)
    }
}

// MARK: - Medium: unified Apple-style

private struct MediumWidgetView: View {
    let s: WatchSnapshotState
    private var isEating: Bool { s.phase == .eating }
    private var calProgress: Double { Double(s.todayCalories) / Double(max(s.dailyCalorieGoal, 1)) }
    private var fastTotal: TimeInterval {
        isEating
            ? TimeInterval(s.eatingWindowEnd.timeIntervalSince(s.eatingWindowStart))
            : TimeInterval(s.phaseEndsAt.timeIntervalSince(s.eatingWindowEnd))
    }
    private var fastElapsed: TimeInterval {
        if isEating {
            return max(Date.now.timeIntervalSince(s.eatingWindowStart), 0)
        } else {
            return max(Date.now.timeIntervalSince(s.eatingWindowEnd), 0)
        }
    }
    private var fastProgress: Double { fastTotal > 0 ? min(fastElapsed / fastTotal, 1.0) : 0 }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: calories ──
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(W.track, lineWidth: 7)
                    Circle().trim(from: 0, to: min(calProgress, 1.0))
                        .stroke(
                            calProgress > 1.0 ? Color.red : W.flame,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("还可以吃").font(.system(size: 8, weight: .medium)).foregroundStyle(W.sub)
                        Text("\(s.remainingCalories)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(W.flame).minimumScaleFactor(0.5)
                        Text("千卡").font(.system(size: 8, weight: .medium)).foregroundStyle(W.sub)
                    }
                }.frame(width: 80, height: 80)

                HStack(spacing: 0) {
                    Text("摄入 ").font(.system(size: 9, weight: .medium)).foregroundStyle(W.sub)
                    Text("\(s.todayCalories)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(W.ink)
                    Text(" / \(s.dailyCalorieGoal)").font(.system(size: 9, weight: .medium)).foregroundStyle(W.sub)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Divider ──
            Rectangle().fill(W.track).frame(width: 0.5)
                .padding(.vertical, 16)

            // ── Right: fasting status ──
            VStack(spacing: 6) {
                Text(s.phaseEndsAt, style: .timer)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(W.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(isEating ? "🍽️ 进食窗口" : "🔥 断食中")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isEating ? W.greenMint : W.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isEating ? W.greenMint : W.blue).opacity(0.12), in: Capsule())

                Text(isEating ? "把握进食窗口" : "保持燃脂节奏")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(W.sub)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.white, for: .widget)
    }
}

// MARK: - Accessory

private struct AccessoryRectangularView: View {
    let s: WatchSnapshotState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.phase == .eating ? "🍽️ 进食中" : "⏱️ 断食中").font(.system(size: 12, weight: .bold))
            Text("还可吃 \(s.remainingCalories) 千卡").font(.system(size: 11, weight: .medium))
            Text(s.phase == .eating
                 ? "至 \(s.eatingWindowEnd.formatted(date: .omitted, time: .shortened))"
                 : "\(s.eatingWindowStart.formatted(date: .omitted, time: .shortened)) 可进食")
                .font(.system(size: 10))
        }
    }
}

private struct AccessoryCircularView: View {
    let s: WatchSnapshotState
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(s.remainingCalories)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5)
                Text("千卡").font(.system(size: 7, weight: .medium))
            }
        }
    }
}

// MARK: - Router

struct FastingLensWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastingLensWidgetEntry
    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(s: entry.snapshot)
        case .accessoryRectangular: AccessoryRectangularView(s: entry.snapshot)
        case .accessoryCircular: AccessoryCircularView(s: entry.snapshot)
        default: SmallWidgetView(s: entry.snapshot)
        }
    }
}

@main
struct FastingLensWidget: Widget {
    let kind = "FastingLensWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastingLensWidgetProvider()) { entry in
            FastingLensWidgetView(entry: entry)
        }
        .configurationDisplayName("断食镜")
        .description("热量、断食状态一目了然。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Previews

private extension WatchSnapshotState {
    /// 进食状态 demo：已吃 820 kcal / 目标 1600，进食窗口还剩 3 小时
    static var eatingDemo: WatchSnapshotState {
        let eatStart = Date.now.addingTimeInterval(-5 * 3600)
        let eatEnd = eatStart.addingTimeInterval(8 * 3600)
        return WatchSnapshotState(
            generatedAt: .now,
            phase: .eating,
            phaseEndsAt: eatEnd,
            todayCalories: 820,
            recentMeals: [],
            dailyCalorieGoal: 1600,
            remainingCalories: 780,
            todayActiveCalories: 220,
            estimatedTDEE: 2100,
            eatingWindowStart: eatStart,
            eatingWindowEnd: eatEnd
        )
    }

    /// 断食状态 demo：已吃 1350 kcal，断食还剩 10 小时
    static var fastingDemo: WatchSnapshotState {
        let eatStart = Date.now.addingTimeInterval(-14 * 3600)
        let eatEnd = eatStart.addingTimeInterval(8 * 3600)
        let phaseEnd = Date.now.addingTimeInterval(10 * 3600)
        return WatchSnapshotState(
            generatedAt: .now,
            phase: .fasting,
            phaseEndsAt: phaseEnd,
            todayCalories: 1350,
            recentMeals: [],
            dailyCalorieGoal: 1600,
            remainingCalories: 250,
            todayActiveCalories: 180,
            estimatedTDEE: 2100,
            eatingWindowStart: eatStart,
            eatingWindowEnd: eatEnd
        )
    }
}

#Preview("Small - 进食中", as: .systemSmall) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .eatingDemo)
}

#Preview("Small - 断食中", as: .systemSmall) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .fastingDemo)
}

#Preview("Medium - 进食中", as: .systemMedium) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .eatingDemo)
}

#Preview("Medium - 断食中", as: .systemMedium) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .fastingDemo)
}

#Preview("锁屏 矩形", as: .accessoryRectangular) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .eatingDemo)
}

#Preview("锁屏 圆形", as: .accessoryCircular) {
    FastingLensWidget()
} timeline: {
    FastingLensWidgetEntry(date: .now, snapshot: .fastingDemo)
}
