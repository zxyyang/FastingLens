import AppFeatures
import Foundation
import WatchConnectivity

extension Notification.Name {
    static let fastingLensSnapshotDidUpdate = Notification.Name("fastingLensSnapshotDidUpdate")
}

final class WatchSyncBridge: NSObject, WCSessionDelegate {
    private let session = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let data = session.receivedApplicationContext["snapshot"] as? Data {
            applySnapshotData(data)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["snapshot"] as? Data {
            applySnapshotData(data)
        }
    }

    private func applySnapshotData(_ data: Data) {
        if let decoded = try? JSONDecoder().decode(WatchSnapshotState.self, from: data) {
            SharedSnapshotStore.save(snapshot: decoded)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .fastingLensSnapshotDidUpdate, object: decoded)
            }
        }
    }

    func send(command: WatchCommand) {
        guard let session else { return }
        guard let data = try? JSONEncoder().encode(command) else { return }
        session.transferUserInfo(["command": data])
    }
}
