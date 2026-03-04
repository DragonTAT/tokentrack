import SwiftUI
import AppKit

@main
struct TokscaleMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = DataStore()

    var body: some Scene {
        // Menu bar popover
        MenuBarExtra {
            PopoverView()
                .environment(store)
        } label: {
            Label("TokenTrack", systemImage: "chart.line.uptrend.xyaxis")
        }
        .menuBarExtraStyle(.window)

        // Dashboard window
        Window("TokenTrack", id: "dashboard") {
            DashboardView()
                .environment(store)
                .frame(minWidth: 600, idealWidth: 800, minHeight: 400, idealHeight: 533)
        }
        .defaultSize(width: 800, height: 533)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installRightClickMonitor()
    }

    /// Listen for right-click on the menu bar status item and show a Quit context menu.
    private func installRightClickMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp]) { event in
            // Only react to right-click on the status bar area
            if event.type == .rightMouseDown {
                DispatchQueue.main.async { self.showQuitMenu() }
                return nil // consume the event
            }
            return event
        }
    }

    private func showQuitMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "TokenTrack", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit TokenTrack", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Pop the menu at the current mouse location
        guard let statusBarItem = NSApp.windows.first(where: { $0.title.contains("NSStatusBarWindow") }) else {
            // Fallback: just pop at mouse position
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            return
        }
        let loc = statusBarItem.convertPoint(fromScreen: NSEvent.mouseLocation)
        menu.popUp(positioning: nil, at: loc, in: statusBarItem.contentView)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
