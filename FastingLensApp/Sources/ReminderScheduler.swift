import AppFeatures
import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifiers = [
        "fasting.phase.ends",
        "fasting.phase.warning"
    ]

    func reschedule(plan: StoredFastingPlan, snapshot: WatchSnapshotState) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard plan.remindersEnabled else { return }

        Task {
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else { return }

            let endDate = snapshot.phaseEndsAt
            guard endDate > .now else { return }

            schedule(
                id: "fasting.phase.ends",
                title: snapshot.phase == .fasting ? "断食阶段已结束" : "进食窗口已结束",
                body: snapshot.phase == .fasting ? "现在可以开始进食了。" : "该重新开始断食了。",
                date: endDate
            )

            let warningDate = endDate.addingTimeInterval(-30 * 60)
            if warningDate > .now {
                schedule(
                    id: "fasting.phase.warning",
                    title: "当前阶段即将结束",
                    body: "还有 30 分钟就要切换阶段了。",
                    date: warningDate
                )
            }
        }
    }

    private func schedule(id: String, title: String, body: String, date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
