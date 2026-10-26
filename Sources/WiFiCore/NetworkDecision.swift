import Foundation

public enum OperatingMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case ask = "Ask before switching"
    case monitorOnly = "Monitor only"
    public var id: String { rawValue }
}

public struct NetworkMeasurement: Equatable, Sendable {
    public let ssid: String
    public let rssi: Int?
    public let latencyMilliseconds: Double?
    public let reachable: Bool?
    public init(ssid: String, rssi: Int?, latencyMilliseconds: Double? = nil, reachable: Bool? = nil) {
        self.ssid = ssid; self.rssi = rssi; self.latencyMilliseconds = latencyMilliseconds; self.reachable = reachable
    }
}

public struct DecisionSettings: Sendable {
    public var minimumRSSIImprovement: Int = 12
    public var sustainedSeconds: TimeInterval = 15
    public var cooldownSeconds: TimeInterval = 180
    public init(minimumRSSIImprovement: Int = 12, sustainedSeconds: TimeInterval = 15, cooldownSeconds: TimeInterval = 180) {
        self.minimumRSSIImprovement = minimumRSSIImprovement; self.sustainedSeconds = sustainedSeconds; self.cooldownSeconds = cooldownSeconds
    }
}

public struct SwitchRecommendation: Equatable, Sendable {
    public let target: String
    public let reason: String
}

public struct SwitchingEngine: Sendable {
    private var improvedSince: Date?
    private var lastSwitchAt: Date?
    private var pendingTarget: String?
    public init() {}

    public mutating func recommendation(current: NetworkMeasurement?, candidates: [NetworkMeasurement], mode: OperatingMode, settings: DecisionSettings, now: Date = .now) -> SwitchRecommendation? {
        guard let current, let currentRSSI = current.rssi else { improvedSince = nil; pendingTarget = nil; return nil }
        let best = candidates.filter { $0.ssid != current.ssid && $0.rssi != nil }
            .max { ($0.rssi ?? -127) < ($1.rssi ?? -127) }
        guard let best, let targetRSSI = best.rssi, targetRSSI - currentRSSI >= settings.minimumRSSIImprovement else {
            improvedSince = nil; pendingTarget = nil; return nil
        }
        if pendingTarget != best.ssid { pendingTarget = best.ssid; improvedSince = now }
        if let lastSwitchAt, now.timeIntervalSince(lastSwitchAt) < settings.cooldownSeconds { return nil }
        guard let improvedSince, now.timeIntervalSince(improvedSince) >= settings.sustainedSeconds else { return nil }
        let why = current.reachable == false ? "Current internet probe failed; the alternative has a stronger Wi-Fi signal." : "Wi-Fi signal is \(targetRSSI - currentRSSI) dB stronger; internet quality on the alternative is not yet measured."
        return SwitchRecommendation(target: best.ssid, reason: why)
    }

    public mutating func recordSwitch(at date: Date = .now) { lastSwitchAt = date; improvedSince = nil; pendingTarget = nil }
}


public enum SwitchVerification: Equatable, Sendable {
    case connected
    case failedOn(String)
    case unknown

    public static func evaluate(target: String, observedSSID: String?) -> SwitchVerification {
        guard let observedSSID else { return .unknown }
        return observedSSID == target ? .connected : .failedOn(observedSSID)
    }

    public var shouldAttemptRecovery: Bool {
        if case .failedOn = self { return true }
        return false
    }
}

public enum NetworkScorer {
    /// Returns nil when the available measurements do not support a meaningful score.
    public static func score(_ measurement: NetworkMeasurement) -> Int? {
        guard let rssi = measurement.rssi else { return nil }
        let wifi = max(0, min(100, (rssi + 90) * 2))
        guard let reachable = measurement.reachable else { return wifi }
        guard reachable else { return min(wifi, 20) }
        guard let latency = measurement.latencyMilliseconds else { return wifi }
        let latencyScore = max(0, min(100, 100 - Int(latency / 5)))
        return wifi * 40 / 100 + latencyScore * 60 / 100
    }
}
