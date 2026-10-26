import XCTest
@testable import WiFiCore

final class NetworkDecisionTests: XCTestCase {
    func testStrongSignalCanStillScorePoorlyWhenInternetIsDown() {
        let wifiOnly = NetworkScorer.score(.init(ssid: "A", rssi: -45))
        let offline = NetworkScorer.score(.init(ssid: "A", rssi: -45, reachable: false))
        XCTAssertGreaterThan(wifiOnly ?? 0, offline ?? 100)
    }

    func testDoesNotRecommendMarginalImprovement() {
        var engine = SwitchingEngine()
        let current = NetworkMeasurement(ssid: "A", rssi: -60, reachable: true)
        let candidate = NetworkMeasurement(ssid: "B", rssi: -54)
        XCTAssertNil(engine.recommendation(current: current, candidates: [candidate], mode: .ask, settings: .init(sustainedSeconds: 0)))
    }

    func testRequiresSustainedImprovement() {
        var engine = SwitchingEngine()
        let current = NetworkMeasurement(ssid: "A", rssi: -75, reachable: true)
        let candidate = NetworkMeasurement(ssid: "B", rssi: -50)
        let now = Date(timeIntervalSince1970: 1000)
        let settings = DecisionSettings(minimumRSSIImprovement: 10, sustainedSeconds: 15, cooldownSeconds: 30)
        XCTAssertNil(engine.recommendation(current: current, candidates: [candidate], mode: .ask, settings: settings, now: now))
        XCTAssertNotNil(engine.recommendation(current: current, candidates: [candidate], mode: .ask, settings: settings, now: now.addingTimeInterval(16)))
    }

    func testCooldownSuppressesNextSwitch() {
        var engine = SwitchingEngine()
        engine.recordSwitch(at: Date(timeIntervalSince1970: 1000))
        let current = NetworkMeasurement(ssid: "A", rssi: -75, reachable: false)
        let candidate = NetworkMeasurement(ssid: "B", rssi: -50)
        let result = engine.recommendation(current: current, candidates: [candidate], mode: .ask, settings: .init(sustainedSeconds: 0, cooldownSeconds: 180), now: Date(timeIntervalSince1970: 1001))
        XCTAssertNil(result)
    }
}

extension NetworkDecisionTests {
    func testAutomaticModeSwitchesToMeaningfullyStrongerNetworkAfterSustainedImprovement() {
        var engine = SwitchingEngine()
        let current = NetworkMeasurement(ssid: "A", rssi: -50, latencyMilliseconds: 25, reachable: true)
        let candidate = NetworkMeasurement(ssid: "B", rssi: -35)
        let now = Date(timeIntervalSince1970: 4000)
        let settings = DecisionSettings(minimumRSSIImprovement: 10, sustainedSeconds: 15)
        XCTAssertNil(engine.recommendation(current: current, candidates: [candidate], mode: .automatic, settings: settings, now: now))
        XCTAssertEqual(engine.recommendation(current: current, candidates: [candidate], mode: .automatic, settings: settings, now: now.addingTimeInterval(16))?.target, "B")
    }

    func testAutomaticModeCanRecommendAfterCurrentProbeFails() {
        var engine = SwitchingEngine()
        let current = NetworkMeasurement(ssid: "A", rssi: -60, reachable: false)
        let candidate = NetworkMeasurement(ssid: "B", rssi: -40)
        let now = Date(timeIntervalSince1970: 2000)
        let settings = DecisionSettings(minimumRSSIImprovement: 10, sustainedSeconds: 0)
        XCTAssertEqual(engine.recommendation(current: current, candidates: [candidate], mode: .automatic, settings: settings, now: now)?.target, "B")
    }

    func testTargetChangeResetsSustainedImprovementTimer() {
        var engine = SwitchingEngine()
        let current = NetworkMeasurement(ssid: "A", rssi: -75, reachable: true)
        let first = NetworkMeasurement(ssid: "B", rssi: -50)
        let second = NetworkMeasurement(ssid: "C", rssi: -49)
        let settings = DecisionSettings(minimumRSSIImprovement: 10, sustainedSeconds: 15)
        let now = Date(timeIntervalSince1970: 3000)
        XCTAssertNil(engine.recommendation(current: current, candidates: [first], mode: .ask, settings: settings, now: now))
        XCTAssertNil(engine.recommendation(current: current, candidates: [second], mode: .ask, settings: settings, now: now.addingTimeInterval(14)))
        XCTAssertEqual(engine.recommendation(current: current, candidates: [second], mode: .ask, settings: settings, now: now.addingTimeInterval(30))?.target, "C")
    }

    func testUnknownSSIDDoesNotTriggerRecovery() {
        XCTAssertEqual(SwitchVerification.evaluate(target: "B", observedSSID: nil), .unknown)
        XCTAssertFalse(SwitchVerification.evaluate(target: "B", observedSSID: nil).shouldAttemptRecovery)
    }

    func testKnownFailedSwitchCanTriggerRecovery() {
        let result = SwitchVerification.evaluate(target: "B", observedSSID: "A")
        XCTAssertEqual(result, .failedOn("A"))
        XCTAssertTrue(result.shouldAttemptRecovery)
    }

    func testSuccessfulSwitchDoesNotTriggerRecovery() {
        let result = SwitchVerification.evaluate(target: "B", observedSSID: "B")
        XCTAssertEqual(result, .connected)
        XCTAssertFalse(result.shouldAttemptRecovery)
    }
}
