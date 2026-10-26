import CoreWLAN
import Foundation
import Network

func wifiInterface() -> CWInterface? {
    CWWiFiClient.shared().interface()
}

func inspectWiFi() {
    guard let interface = wifiInterface() else {
        print("Wi-Fi interface: unavailable")
        return
    }

    print("Interface: \(interface.interfaceName ?? "unknown")")
    print("Power: \(interface.powerOn() ? "on" : "off")")
    print("SSID: \(interface.ssid() ?? "unavailable")")
    print("BSSID: \(interface.bssid() ?? "unavailable")")
    print("RSSI: \(interface.rssiValue()) dBm")
    print("Noise: \(interface.noiseMeasurement()) dBm")
    print("Transmit rate: \(interface.transmitRate()) Mbps")
    print("Security: \(interface.security())")
}

func scanWiFi() {
    guard let interface = wifiInterface() else {
        print("Cannot scan: Wi-Fi interface unavailable")
        return
    }
    do {
        let networks = try interface.scanForNetworks(withName: nil, includeHidden: false)
        for network in networks.sorted(by: { ($0.rssiValue) > ($1.rssiValue) }) {
            print("SSID=\(network.ssid ?? "<hidden>") RSSI=\(network.rssiValue) dBm BSSID=\(network.bssid ?? "unknown")")
        }
        print("Networks found: \(networks.count)")
    } catch {
        fputs("Scan failed: \(error)\n", stderr)
    }
}

func probeInternet(host: String = "1.1.1.1", port: UInt16 = 443) {
    let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    let started = DispatchTime.now()
    let semaphore = DispatchSemaphore(value: 0)
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
            print("TCP connect to \(host):\(port): reachable, \(String(format: "%.1f", milliseconds)) ms (includes DNS/connection setup)")
            connection.cancel()
            semaphore.signal()
        case .failed(let error):
            print("TCP connect to \(host):\(port): failed (\(error))")
            connection.cancel()
            semaphore.signal()
        case .cancelled:
            semaphore.signal()
        default:
            break
        }
    }
    connection.start(queue: .global())
    if semaphore.wait(timeout: .now() + 8) == .timedOut {
        print("TCP connect to \(host):\(port): timed out")
        connection.cancel()
    }
}

func switchToKnownSSID(_ ssid: String) {
    guard let interface = wifiInterface() else {
        fputs("Cannot switch: Wi-Fi interface unavailable\n", stderr)
        exit(2)
    }
    do {
        let isSaved = interface.configuration()?.networkProfiles.contains { ($0 as? CWNetworkProfile)?.ssid == ssid } ?? false
        guard isSaved else {
            fputs("Refusing to switch: \(ssid) is not in macOS's saved Wi-Fi profiles.\n", stderr)
            exit(3)
        }
        let networks = try interface.scanForNetworks(withSSID: Data(ssid.utf8), includeHidden: false)
        guard let network = networks.first else {
            fputs("Saved network is not currently visible: \(ssid)\n", stderr)
            exit(3)
        }
        try interface.associate(to: network, password: nil)
        print("CoreWLAN association request sent for saved network \(ssid). Check the active route and TCP probe; SSID verification still requires Location Services permission.")
    } catch {
        fputs("Association failed for \(ssid): \(error)\n", stderr)
        exit(4)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "scan":
    scanWiFi()
case "probe":
    probeInternet()
case "switch" where arguments.count >= 2:
    switchToKnownSSID(arguments[1])
case "all":
    inspectWiFi()
    scanWiFi()
    probeInternet()
default:
    inspectWiFi()
    print("\nUsage: seamless-wifi-probe [all|scan|probe|switch <visible-ssid>]")
}
