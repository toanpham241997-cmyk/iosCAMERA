import Foundation
import Vision
import CoreML
import CoreVideo

/// Confined to CameraService's serial queue; inference never runs on the UI thread.
final class VisionEngine {
    private var modelRequest: VNCoreMLRequest?
    private var sequence = VNSequenceRequestHandler()
    private var trackers: [(Detection, VNTrackObjectRequest)] = []
    private var associator = TrackAssociator()
    private var lastDetections: [Detection] = []
    private var lastDetectionTime: Double = -10
    private(set) var modelName = "Vision · Người, chó, mèo"
    private(set) var modelIssue: String?
    private var hazard = HazardEngine()
    private var hazardState = HazardState()

    init() {
        guard let url = Bundle.main.url(forResource: "YOLOv3TinyInt8LUT", withExtension: "mlmodelc") else {
            modelIssue = "Chưa có mô hình 80 lớp. Đang dùng nhận diện người, chó và mèo của Apple Vision."
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            modelRequest = VNCoreMLRequest(model: try VNCoreMLModel(for: model))
            modelRequest?.imageCropAndScaleOption = .scaleFill
            modelName = "YOLO Tiny · 80 lớp · Offline"
        } catch {
            modelIssue = "Không nạp được mô hình: \(error.localizedDescription). Đang dùng Apple Vision."
        }
    }

    func reset() {
        trackers = []
        lastDetections = []
        sequence = VNSequenceRequestHandler()
        lastDetectionTime = -10
        hazard.reset()
        hazardState = HazardState()
    }

    func process(_ buffer: CVPixelBuffer, time: Double, settings: ScanSettings,
                 constrained: Bool) throws -> (objects: [Detection], hazard: HazardState, detected: Bool) {
        let interval = constrained ? 0.65 : 0.25
        if time - lastDetectionTime >= interval {
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
            var found: [Detection] = []
            if let modelRequest {
                try handler.perform([modelRequest])
                guard let results = modelRequest.results as? [VNRecognizedObjectObservation] else {
                    throw NSError(domain: "AIMat.Vision", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Mô hình không trả về khung nhận diện tương thích Vision."])
                }
                found = results.compactMap { observation in
                    guard let label = observation.labels.first,
                          label.confidence >= settings.confidence,
                          let box = BoxGeometry.clamped(observation.boundingBox) else { return nil }
                    return Detection(id: 0, label: label.identifier.lowercased(), confidence: label.confidence, box: box)
                }
            } else {
                let humans = VNDetectHumanRectanglesRequest()
                humans.upperBodyOnly = false
                let animals = VNRecognizeAnimalsRequest()
                try handler.perform([humans, animals])
                found += (humans.results ?? []).compactMap { item in
                    guard item.confidence >= settings.confidence,
                          let box = BoxGeometry.clamped(item.boundingBox) else { return nil }
                    return Detection(id: 0, label: "person", confidence: item.confidence, box: box)
                }
                found += (animals.results ?? []).compactMap { item in
                    guard let label = item.labels.first, label.confidence >= settings.confidence,
                          let box = BoxGeometry.clamped(item.boundingBox) else { return nil }
                    return Detection(id: 0, label: label.identifier.lowercased(), confidence: label.confidence, box: box)
                }
            }
            // Bound work and avoid duplicate boxes from detector output.
            var kept: [Detection] = []
            for item in found.sorted(by: { $0.confidence > $1.confidence }) {
                if !kept.contains(where: { $0.label == item.label && BoxGeometry.iou($0.box, item.box) > 0.45 }) {
                    kept.append(item)
                }
                if kept.count == 20 { break }
            }
            let objects = associator.associate(kept, with: lastDetections, elapsed: time - lastDetectionTime)
            lastDetectionTime = time
            lastDetections = objects
            sequence = VNSequenceRequestHandler()
            trackers = objects.map { item in
                let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: item.box))
                request.trackingLevel = .fast
                return (item, request)
            }
            hazardState = hazard.evaluate(objects, at: time, enabled: settings.warnings)
            return (objects, hazardState, true)
        }

        if !settings.warnings {
            hazard.reset()
            hazardState = HazardState()
        }
        guard !trackers.isEmpty else { return ([], hazardState, false) }
        try sequence.perform(trackers.map { $0.1 }, on: buffer, orientation: .up)
        var objects: [Detection] = []
        trackers = trackers.compactMap { item, request in
            guard let result = request.results?.first as? VNDetectedObjectObservation,
                  result.confidence >= 0.4,
                  let box = BoxGeometry.clamped(result.boundingBox) else { return nil }
            var updated = item
            updated.box = box
            updated.isTracked = true
            request.inputObservation = result
            objects.append(updated)
            return (updated, request)
        }
        return (objects, hazardState, false)
    }
}
