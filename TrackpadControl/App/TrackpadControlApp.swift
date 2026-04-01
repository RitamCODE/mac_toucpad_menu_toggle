import SwiftUI

@main
struct TrackpadControlApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("Trackpad Control", systemImage: "cursorarrow.motionlines") {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
