import XCTest
import CoreGraphics
@testable import AIMatCore

final class CoreTests: XCTestCase {
    func object(id: Int = 1, label: String = "motorcycle", box: CGRect = CGRect(x: 0.3, y: 0.15, width: 0.4, height: 0.6), confidence: Float = 0.9) -> Detection {
        Detection(id: id, label: label, confidence: confidence, box: box)
    }

    func testAspectFitAndVisionYAxis() {
        let fitted = BoxGeometry.imageRect(image: CGSize(width: 720, height: 1280), canvas: CGSize(width: 335, height: 400))
        XCTAssertEqual(fitted.width, 225, accuracy: 0.001)
        XCTAssertEqual(fitted.minX, 55, accuracy: 0.001)
        let top = BoxGeometry.displayRect(CGRect(x: 0, y: 0.75, width: 0.5, height: 0.25), inside: fitted)
        XCTAssertEqual(top.minY, 0, accuracy: 0.001)
        XCTAssertEqual(top.minX, 55, accuracy: 0.001)
        XCTAssertEqual(top.height, 100, accuracy: 0.001)
    }

    func testInvalidAndOutOfBoundsBoxes() {
        XCTAssertNil(BoxGeometry.clamped(CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)))
        XCTAssertNil(BoxGeometry.clamped(CGRect(x: 2, y: 0, width: 1, height: 1)))
        XCTAssertEqual(BoxGeometry.clamped(CGRect(x: -0.1, y: 0.2, width: 0.3, height: 0.5))?.minX, 0)
        XCTAssertEqual(BoxGeometry.iou(.zero, .zero), 0)
    }

    func testTracksKeepIDsAndCannotMatchTwice() {
        var tracker = TrackAssociator()
        let initial = tracker.associate([object()], with: [], elapsed: 0.25)
        let next = tracker.associate([object(), object(confidence: 0.7)], with: initial, elapsed: 0.25)
        XCTAssertEqual(next.first?.id, initial.first?.id)
        XCTAssertNotEqual(next.first?.id, next.last?.id)
        let changed = tracker.associate([object(label: "person")], with: initial, elapsed: 0.25)
        XCTAssertNotEqual(changed.first?.id, initial.first?.id)
    }

    func testWarningNeedsDwellAndReleasesAfterEvidenceGone() {
        var engine = HazardEngine()
        XCTAssertFalse(engine.evaluate([object()], at: 10, enabled: true).isWarning)
        XCTAssertFalse(engine.evaluate([object()], at: 10.3, enabled: true).isWarning)
        XCTAssertTrue(engine.evaluate([object()], at: 10.7, enabled: true).isWarning)
        XCTAssertTrue(engine.evaluate([], at: 11.0, enabled: true).isWarning)
        XCTAssertFalse(engine.evaluate([], at: 12.6, enabled: true).isWarning)
    }

    func testNoWarningForPersonLowConfidenceOrOffCenterVehicle() {
        for item in [object(label: "person"), object(confidence: 0.4), object(box: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.7))] {
            var engine = HazardEngine()
            _ = engine.evaluate([item], at: 0, enabled: true)
            XCTAssertFalse(engine.evaluate([item], at: 5, enabled: true).isWarning)
        }
    }

    func testTrackingDriftCannotGenerateWarning() {
        var engine = HazardEngine()
        var tracked = object()
        tracked.isTracked = true
        _ = engine.evaluate([tracked], at: 0, enabled: true)
        XCTAssertFalse(engine.evaluate([tracked], at: 3, enabled: true).isWarning)
    }

    func testDisableResetsImmediately() {
        var engine = HazardEngine()
        _ = engine.evaluate([object()], at: 0, enabled: true)
        XCTAssertTrue(engine.evaluate([object()], at: 1, enabled: true).isWarning)
        XCTAssertFalse(engine.evaluate([object()], at: 1.1, enabled: false).isWarning)
        XCTAssertFalse(engine.evaluate([object()], at: 1.2, enabled: true).isWarning)
    }

    func testOcclusionRestartsDwellAndDifferentIDsCannotAccumulate() {
        var engine = HazardEngine()
        _ = engine.evaluate([object()], at: 0, enabled: true)
        _ = engine.evaluate([], at: 0.5, enabled: true)
        XCTAssertFalse(engine.evaluate([object()], at: 0.8, enabled: true).isWarning)
        XCTAssertFalse(engine.evaluate([object(id: 2)], at: 1.2, enabled: true).isWarning)
        XCTAssertTrue(engine.evaluate([object(id: 2)], at: 1.9, enabled: true).isWarning)
    }

    func testGrowingVehicleCanWarnWithoutAbsoluteDistanceClaim() {
        var engine = HazardEngine()
        var item = object(box: CGRect(x: 0.35, y: 0.2, width: 0.25, height: 0.4))
        item.growthPerSecond = 0.7
        _ = engine.evaluate([item], at: 0, enabled: true)
        XCTAssertTrue(engine.evaluate([item], at: 0.8, enabled: true).isWarning)
    }
}
