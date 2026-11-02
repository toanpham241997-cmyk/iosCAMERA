import Foundation
import CoreGraphics

struct HazardState: Equatable {
    var isWarning = false
    var reason = "Chưa có tín hiệu cảnh báo"
    var objectIDs: Set<Int> = []
}

/// Visual heuristics only. No GPS, scene safety score, real distance or temperature inference.
struct HazardEngine {
    private var candidateSince: [Int: Double] = [:]
    private var lastEvidence: Double?
    private var active = HazardState()
    var dwell: Double = 0.65
    var releaseDelay: Double = 1.8

    mutating func reset() {
        candidateSince = [:]
        lastEvidence = nil
        active = HazardState()
    }

    mutating func evaluate(_ objects: [Detection], at time: Double, enabled: Bool) -> HazardState {
        guard enabled else { reset(); return active }
        let zone = CGRect(x: 0.23, y: 0.08, width: 0.54, height: 0.80)
        let candidates = objects.filter {
            !$0.isTracked && $0.confidence >= 0.60 && ObjectLabels.vehicles.contains($0.label)
                && zone.contains(CGPoint(x: $0.box.midX, y: $0.box.midY))
                && ($0.area >= 0.18 || ($0.area >= 0.06 && $0.growthPerSecond >= 0.45))
        }
        let ids = Set(candidates.map(\.id))
        candidateSince = candidateSince.filter { ids.contains($0.key) }
        for id in ids where candidateSince[id] == nil { candidateSince[id] = time }
        let confirmed = ids.filter { time - (candidateSince[$0] ?? time) >= dwell }
        if !confirmed.isEmpty {
            lastEvidence = time
            active = HazardState(isWarning: true,
                reason: "Phương tiện chiếm vùng trung tâm hoặc có dấu hiệu tiến gần. Hãy quan sát và giữ khoảng cách.",
                objectIDs: Set(confirmed))
        } else if let lastEvidence, time - lastEvidence < releaseDelay {
            // Keep the banner through short occlusions / missed detector frames.
        } else {
            active = HazardState()
        }
        return active
    }
}
