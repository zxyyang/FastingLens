import AppFeatures
import Foundation
import WatchConnectivity

extension Notification.Name {
    static let fastingLensWatchCommandDidReceive = Notification.Name("fastingLensWatchCommandDidReceive")
}

final class PhoneWatchSyncBridge: NSObject, WCSessionDelegate {
    private let session = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func push(snapshot: WatchSnapshotState) {
        guard let session else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? session.updateApplicationContext(["snapshot": data])
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["command"] as? Data,
              let command = try? JSONDecoder().decode(WatchCommand.self, from: data) else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fastingLensWatchCommandDidReceive, object: command)
        }
    }
}
