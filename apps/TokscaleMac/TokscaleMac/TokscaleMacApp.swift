import SwiftUI

@main
struct TokscaleMacApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        // Menu bar popover
        MenuBarExtra {
            PopoverView()
                .environment(store)
        } label: {
            Label("TokenTrack", systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)

        // Dashboard window
        Window("TokenTrack", id: "dashboard") {
            DashboardView()
                .environment(store)
                .frame(minWidth: 900, idealWidth: 1200, minHeight: 600, idealHeight: 800)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
