import AppFeatures
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshotState
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, snapshot: SharedSnapshotStore.initialSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        let snap = SharedSnapshotStore.loadSnapshot() ?? SharedSnapshotStore.initialSnapshot()
        completion(WatchComplicationEntry(date: .now, snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let snap = SharedSnapshotStore.loadSnapshot() ?? SharedSnapshotStore.initialSnapshot()
        // Generate multiple entries so progress updates over time
        var entries: [WatchComplicationEntry] = []
        let now = Date.now
        for minuteOffset in stride(from: 0, through: 60, by: 5) {
            let entryDate = now.addingTimeInterval(Double(minuteOffset) * 60)
            entries.append(WatchComplicationEntry(date: entryDate, snapshot: snap))
        }
        let next = min(snap.phaseEndsAt, now.addingTimeInterval(60 * 60))
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - Helpers

private extension WatchSnapshotState {
    var isEating: Bool { phase == .eating }

    /// How much of the current phase has elapsed: 0.0 → 1.0
    func phaseProgress(at date: Date) -> Double {
        let eatingDuration = eatingWindowEnd.timeIntervalSince(eatingWindowStart)
        guard eatingDuration > 0 else { return 0 }

        let total: TimeInterval
        let elapsed: TimeInterval

        if isEating {
            total = eatingDuration
            elapsed = max(date.timeIntervalSince(eatingWindowStart), 0)
        } else {
            // fasting duration = 24h cycle minus eating window
            total = max(24 * 3600 - eatingDuration, 1)
            let remaining = max(phaseEndsAt.timeIntervalSince(date), 0)
            elapsed = total - remaining
        }

        guard total > 0 else { return 0 }
        return max(0, min(elapsed / total, 1.0))
    }

    /// SF Symbol name for current phase
    var phaseIcon: String {
        isEating ? "fork.knife" : "timer"
    }
}

// MARK: - Router

struct ComplicationRouter: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCorner:
            CornerView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(s: entry.snapshot)
        default:
            CircularView(entry: entry)
        }
    }
}

// MARK: - Corner (like the noise/decibel style)

private struct CornerView: View {
    let entry: WatchComplicationEntry
    private var s: WatchSnapshotState { entry.snapshot }
    private var progress: Double { s.phaseProgress(at: entry.date) }

    var body: some View {
        Image(systemName: s.isEating ? "fork.knife.circle.fill" : "hand.raised.circle.fill")
            .font(.system(size: 22, weight: .medium))
            .widgetLabel {
                ProgressView(value: progress)
                    .tint(s.isEating ? .green : .blue)
            }
    }
}

// MARK: - Circular

private struct CircularView: View {
    let entry: WatchComplicationEntry
    private var s: WatchSnapshotState { entry.snapshot }
    private var progress: Double { s.phaseProgress(at: entry.date) }

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: s.phaseIcon)
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            Text("\(Int(progress * 100))")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(s.isEating ? .green : .blue)
    }
}

// MARK: - Rectangular

private struct RectangularView: View {
    let entry: WatchComplicationEntry
    private var s: WatchSnapshotState { entry.snapshot }
    private var progress: Double { s.phaseProgress(at: entry.date) }

    var body: some View {
        HStack(spacing: 6) {
            Gauge(value: progress) {
                Image(systemName: s.phaseIcon)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(s.isEating ? .green : .blue)
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: s.phaseIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(s.isEating ? "进食中" : "断食中")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                Text(s.phaseEndsAt, style: .timer)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("余\(s.remainingCalories)千卡")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Inline

private struct InlineView: View {
    let s: WatchSnapshotState
    var body: some View {
        ViewThatFits {
            Label("\(s.isEating ? "进食中" : "断食中") · 余\(s.remainingCalories)千卡", systemImage: s.phaseIcon)
            Label("\(s.remainingCalories)kcal", systemImage: s.phaseIcon)
        }
    }
}

// MARK: - Widget

struct FastingLensWatchComplication: Widget {
    let kind = "FastingLensWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            ComplicationRouter(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("断食镜")
        .description("断食进度、热量一目了然")
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

@main
struct FastingLensWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        FastingLensWatchComplication()
    }
}
