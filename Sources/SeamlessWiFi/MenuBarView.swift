import AppKit
import SwiftUI
import WiFiCore

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.settingsOpen {
                settingsView.frame(width: 360).padding(22)
            } else {
                mainPopover
            }
        }
        .background(.regularMaterial)
    }

    private var mainPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 14)
            connectionSummary.padding(14)
            Divider().padding(.horizontal, 14)
            networkList.padding(14)
            if let recommendation = model.recommendation { recommendationCard(recommendation).padding(.horizontal, 14).padding(.bottom, 12) }
            Divider().padding(.horizontal, 14)
            footer.padding(14)
        }
        .frame(width: 368)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(.blue.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Seamless WiFi").font(.headline)
                HStack(spacing: 5) {
                    Circle().fill(model.isSwitching ? .orange : .green).frame(width: 7, height: 7)
                    Text(model.isSwitching ? "Switching" : model.mode == .automatic ? "Monitoring · Auto mode" : "Monitoring · \(model.mode.rawValue)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Refresh now")
        }
        .padding(14)
    }

    private var connectionSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("CURRENT CONNECTION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "wifi.circle.fill").font(.system(size: 28)).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.currentSSID ?? "Network name unavailable").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text("BSSID  \(model.currentBSSID ?? "Unavailable")").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill").foregroundStyle(signalColor)
                        Text(model.currentRSSI.map { "\($0) dBm" } ?? "— dBm").monospacedDigit()
                    }.font(.caption)
                    Text(model.qualityText).font(.caption2.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 3)
                        .background(signalColor.opacity(0.12), in: Capsule()).foregroundStyle(signalColor)
                }
            }
            HStack(alignment: .top, spacing: 0) {
                metric(title: "TCP CONNECT", value: model.latency.map { "\(Int($0)) ms" } ?? "—", footnote: "to internet probe")
                Spacer(minLength: 4)
                metric(title: "INTERNET", value: model.internetState, footnote: nil, color: model.tcpReachable == true ? .green : model.tcpReachable == false ? .orange : .secondary)
            }
            Text("Wi-Fi signal and internet health are measured separately.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var networkList: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Available Networks").font(.subheadline.weight(.semibold))
                Spacer()
                Text("WI-FI SIGNAL").font(.caption2).foregroundStyle(.tertiary)
            }
            if model.networks.isEmpty {
                Text("Network names are hidden. Allow Location Services to view nearby networks.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 4)
            } else {
                ForEach(model.networks.filter { $0.isCurrent || $0.isKnown }.prefix(5)) { network in
                    Button {
                        guard !network.isCurrent else { return }
                        model.switchTo(network.ssid)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "wifi").font(.system(size: 14, weight: .semibold)).foregroundStyle(network.isCurrent ? .blue : .secondary)
                                .frame(width: 25)
                            Text(network.ssid).font(.system(size: 13, weight: network.isCurrent ? .medium : .regular)).lineLimit(1)
                            Spacer(minLength: 4)
                            if network.isCurrent {
                                Label("Connected", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(network.rssi.map { "\($0) dBm" } ?? "—")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .disabled(network.isCurrent || model.isSwitching)
                    .help(network.isCurrent ? "Currently connected" : "Switch to \(network.ssid)")
                }
            }
            HStack {
                Text("Last checked").foregroundStyle(.tertiary)
                Spacer()
                Text(model.lastCheckedAt, style: .relative).foregroundStyle(.secondary)
            }.font(.caption2).padding(.top, 3)
        }
    }

    private func recommendationCard(_ recommendation: SwitchRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Better network available").font(.caption.weight(.semibold))
                    Text(recommendation.target).font(.subheadline.weight(.semibold))
                }
                Spacer()
            }
            Text(recommendation.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.mode == .ask {
                Button("Switch to \(recommendation.target)") { model.switchTo(recommendation.target) }
                    .buttonStyle(.borderedProminent).controlSize(.small).frame(maxWidth: .infinity)
            }
        }
        .padding(11)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.blue.opacity(0.18), lineWidth: 1))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { model.settingsOpen = true } label: { Label("Settings…", systemImage: "gearshape.fill") }.buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
            Text(model.statusMessage).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "gearshape.fill").foregroundStyle(.blue)
                Text("Settings").font(.title2.bold())
                Spacer()
                Button("Done") { model.settingsOpen = false }.keyboardShortcut(.defaultAction)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Switching Mode").font(.headline)
                ForEach(OperatingMode.allCases) { mode in
                    Button { model.mode = mode } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: model.mode == mode ? "largecircle.fill.circle" : "circle").foregroundStyle(model.mode == mode ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                                Text(description(for: mode)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Minimum signal improvement").font(.headline); Spacer(); Text("\(Int(model.minimumRSSIImprovement)) dB").foregroundStyle(.secondary) }
                Slider(value: $model.minimumRSSIImprovement, in: 6...24, step: 1)
                Text("A stronger Wi-Fi signal alone does not guarantee better internet performance.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Switch cooldown").font(.headline)
                    Spacer()
                    Text(cooldownLabel).foregroundStyle(.secondary)
                }
                Slider(value: $model.cooldownSeconds, in: 30...600, step: 30)
                Text("Wait this long after a switch before another automatic switch.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button("Open Location Services Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!) }
                .font(.caption)
        }
    }

    private func metric(title: String, value: String, footnote: String?, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            if let footnote { Text(footnote).font(.caption2).foregroundStyle(.tertiary) }
        }
    }

    private var signalColor: Color {
        switch model.qualityText {
        case "Excellent", "Good": .green
        case "Fair": .orange
        default: .secondary
        }
    }

    private var cooldownLabel: String {
        let seconds = Int(model.cooldownSeconds)
        return seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds) sec"
    }

    private func description(for mode: OperatingMode) -> String {
        switch mode {
        case .automatic: "Switch when a better network stays available."
        case .ask: "Recommend a network and let me decide."
        case .monitorOnly: "Track connection quality without switching."
        }
    }
}
