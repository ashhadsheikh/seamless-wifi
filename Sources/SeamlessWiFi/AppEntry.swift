import AppKit
import SwiftUI
import WiFiCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Seamless WiFi")
            button.image?.isTemplate = true
            button.title = "Seamless"
            button.toolTip = "Seamless WiFi"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(model: model))
        installOutsideClickMonitors()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func installOutsideClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if let popoverWindow = self.popover.contentViewController?.view.window,
               event.window === popoverWindow {
                return event
            }
            let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow)
            self.closePopoverIfClickedOutside(at: screenPoint)
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.closePopoverIfClickedOutside()
            }
        }
    }

    private func closePopoverIfClickedOutside(at point: NSPoint? = nil) {
        guard popover.isShown else { return }
        let location = point ?? NSEvent.mouseLocation
        let popoverFrame = popover.contentViewController?.view.window?.frame
        if popoverFrame?.contains(location) == true { return }

        if let button = statusItem?.button,
           let window = button.window,
           window.convertToScreen(button.convert(button.bounds, to: nil)).contains(location) {
            return
        }
        popover.performClose(nil)
    }
}

@main
struct SeamlessWiFiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
