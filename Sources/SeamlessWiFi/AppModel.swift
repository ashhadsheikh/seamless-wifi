import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Network
import Security
import WiFiCore

struct WiFiReading: Identifiable {
    var id: String { ssid }
    let ssid: String
    let rssi: Int?
    let isCurrent: Bool
    let isKnown: Bool
    var latency: Double? = nil
    var reachable: Bool? = nil
}

@MainActor final class AppModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var currentSSID: String?
    @Published var currentRSSI: Int?
    @Published var currentBSSID: String?
    @Published var lastCheckedAt = Date()
    @Published var currentNoise: Int?
    @Published var transmitRate: Double?
    @Published var networks: [WiFiReading] = []
    @Published var pathOnline = false
    @Published var tcpReachable: Bool?
    @Published var latency: Double?
    @Published var lastProbeMessage = "Checking internet…"
    @Published var recommendation: SwitchRecommendation?
    @Published var statusMessage = "Starting monitor…"
    @Published var isSwitching = false
    @Published var mode: OperatingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "operatingMode") }
    }
    @Published var minimumRSSIImprovement: Double {
        didSet { UserDefaults.standard.set(minimumRSSIImprovement, forKey: "minimumRSSIImprovement") }
    }
    @Published var cooldownSeconds: Double {
        didSet { UserDefaults.standard.set(cooldownSeconds, forKey: "cooldownSeconds") }
    }
    @Published var settingsOpen = false

    private let client = CWWiFiClient.shared()
    private let location = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SeamlessWiFi.path")
    private var engine = SwitchingEngine()
    private var monitorTimer: Timer?
    private var lastProbe = Date.distantPast

    override init() {
        mode = OperatingMode(rawValue: UserDefaults.standard.string(forKey: "operatingMode") ?? OperatingMode.automatic.rawValue) ?? .automatic
        minimumRSSIImprovement = UserDefaults.standard.object(forKey: "minimumRSSIImprovement") as? Double ?? 12
        cooldownSeconds = UserDefaults.standard.object(forKey: "cooldownSeconds") as? Double ?? 180
        super.init()
        location.delegate = self
        requestLocationIfNeeded()
        pathMonitor.pathUpdateHandler = { [weak self] path in Task { @MainActor in self?.pathOnline = path.status == .satisfied } }
        pathMonitor.start(queue: queue)
        refresh()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }

    var icon: String { currentSSID == nil ? "wifi.exclamationmark" : "wifi" }
    var qualityText: String { guard let currentRSSI else { return "Unavailable" }; return currentRSSI >= -55 ? "Excellent" : currentRSSI >= -65 ? "Good" : currentRSSI >= -75 ? "Fair" : "Weak" }
    var internetState: String {
        guard pathOnline else { return "No path" }
        guard let tcpReachable else { return "Checking…" }
        return tcpReachable ? "Reachable" : "Probe failed"
    }
    var internetText: String {
        guard pathOnline else { return "No network path" }
        guard let tcpReachable else { return "Checking internet…" }
        guard tcpReachable else { return "Probe failed" }
        return latency.map { "TCP reachable · \(Int($0)) ms" } ?? "TCP reachable"
    }

    func requestLocationIfNeeded() {
        if #available(macOS 11.0, *) { location.requestWhenInUseAuthorization() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { refresh() }

    func refresh() {
        guard let interface = client.interface(), interface.powerOn() else { statusMessage = "Wi-Fi is unavailable or turned off."; return }
        let ssid = interface.ssid()
        currentSSID = ssid
        currentRSSI = interface.rssiValue()
        currentBSSID = interface.bssid()
        lastCheckedAt = .now
        currentNoise = interface.noiseMeasurement()
        transmitRate = interface.transmitRate()
        do {
            let results = try interface.scanForNetworks(withName: nil, includeHidden: false)
            let knownSSIDs = Set(interface.configuration()?.networkProfiles.compactMap { ($0 as? CWNetworkProfile)?.ssid } ?? [])
            var visible: [WiFiReading] = results.compactMap { network in
                guard let name = network.ssid, !name.isEmpty else { return nil }
                return WiFiReading(ssid: name, rssi: network.rssiValue, isCurrent: name == ssid, isKnown: knownSSIDs.contains(name))
            }
            if let ssid, !visible.contains(where: { $0.isCurrent }) { visible.insert(WiFiReading(ssid: ssid, rssi: currentRSSI, isCurrent: true, isKnown: knownSSIDs.contains(ssid)), at: 0) }
            networks = visible.sorted { ($0.rssi ?? -127) > ($1.rssi ?? -127) }
            statusMessage = ssid == nil ? "SSID hidden until Location Services permission is granted." : "Monitoring · refreshed just now"
        } catch {
            statusMessage = "Wi-Fi scan unavailable: \(error.localizedDescription)"
        }
        if Date().timeIntervalSince(lastProbe) > 15 { lastProbe = .now; probeInternet() }
        updateRecommendation()
    }

    private func probeInternet() {
        let connection = NWConnection(host: "1.1.1.1", port: 443, using: .tcp)
        let start = DispatchTime.now().uptimeNanoseconds
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                Task { @MainActor in self?.latency = elapsed; self?.tcpReachable = true; self?.lastProbeMessage = "TCP connection established" }
                connection.cancel()
            case .failed(let error):
                Task { @MainActor in self?.latency = nil; self?.tcpReachable = false; self?.lastProbeMessage = "Probe failed: \(error.localizedDescription)" }
                connection.cancel()
            default: break
            }
        }
        connection.start(queue: queue)
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            if connection.state != .ready { Task { @MainActor in self.tcpReachable = false; self.latency = nil; self.lastProbeMessage = "Probe timed out" } }
            connection.cancel()
        }
    }

    private func updateRecommendation() {
        let current = currentSSID.map { NetworkMeasurement(ssid: $0, rssi: currentRSSI, latencyMilliseconds: latency, reachable: tcpReachable) }
        let candidates = networks.filter(\.isKnown).map { NetworkMeasurement(ssid: $0.ssid, rssi: $0.rssi) }
        let settings = DecisionSettings(minimumRSSIImprovement: Int(minimumRSSIImprovement), cooldownSeconds: cooldownSeconds)
        recommendation = engine.recommendation(current: current, candidates: candidates, mode: mode, settings: settings)
        if mode == .automatic, let recommendation, !isSwitching { switchTo(recommendation.target) }
    }

    func switchTo(_ ssid: String) {
        guard !isSwitching, let interface = client.interface() else { return }
        let savedSSIDs = interface.configuration()?.networkProfiles.compactMap { ($0 as? CWNetworkProfile)?.ssid } ?? []
        guard savedSSIDs.contains(ssid) else { statusMessage = "This network is not saved by macOS, so Seamless WiFi cannot switch to it."; return }
        isSwitching = true
        statusMessage = "Preparing to switch…"
        let switcher = NetworkSwitcher(interface: interface)
        Task { @MainActor [weak self, switcher] in
            guard let self else { return }
            do {
                self.statusMessage = "Switching to \(ssid)…"
                try await switcher.switchToSavedNetwork(ssid: ssid)
                self.engine.recordSwitch()
                self.statusMessage = "Switch request sent. Verifying connection…"
                try? await Task.sleep(for: .seconds(10))
                self.refresh()
                self.isSwitching = false
                switch SwitchVerification.evaluate(target: ssid, observedSSID: self.currentSSID) {
                case .connected:
                    self.statusMessage = "Connected to \(ssid)."
                case .failedOn(let observed):
                    self.statusMessage = "Could not connect to \(ssid); still on \(observed)."
                case .unknown:
                    self.statusMessage = "macOS hid the network name, so the switch could not be verified."
                }
            } catch {
                self.isSwitching = false
                self.statusMessage = "Switch failed: \(error.localizedDescription)"
            }
        }
    }
}

private final class NetworkSwitcher: @unchecked Sendable {
    private let interface: CWInterface
    private static let credentialCache = WiFiCredentialCache()

    init(interface: CWInterface) { self.interface = interface }

    func switchToSavedNetwork(ssid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let data = Data(ssid.utf8)
                    let found = try interface.scanForNetworks(withSSID: data, includeHidden: false)
                    guard let candidate = found.first else {
                        throw NSError(domain: "SeamlessWiFi", code: 1, userInfo: [NSLocalizedDescriptionKey: "This saved network is not currently visible."])
                    }
                    let password: String
                    if let cached = Self.credentialCache.password(for: data) {
                        password = cached
                    } else if let saved = Self.savedWiFiPassword(for: data) {
                        // Cache immediately after Keychain access. Association can fail
                        // independently, and retrying must not re-open Keychain each time.
                        Self.credentialCache.store(saved, for: data)
                        password = saved
                    } else {
                        throw NSError(domain: "SeamlessWiFi", code: 2, userInfo: [NSLocalizedDescriptionKey: "macOS did not provide a saved credential for this network."])
                    }
                    try interface.associate(to: candidate, password: password)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func savedWiFiPassword(for ssid: Data) -> String? {
        for domain: CWKeychainDomain in [.user, .system] {
            var password: NSString?
            let status = CWKeychainFindWiFiPassword(domain, ssid, &password)
            if status == errSecSuccess, let password { return password as String }
        }
        return nil
    }
}

private final class WiFiCredentialCache: @unchecked Sendable {
    private let lock = NSLock()
    private var passwords: [Data: String] = [:]

    func password(for ssid: Data) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return passwords[ssid]
    }

    func store(_ password: String, for ssid: Data) {
        lock.lock()
        defer { lock.unlock() }
        passwords[ssid] = password
    }
}
