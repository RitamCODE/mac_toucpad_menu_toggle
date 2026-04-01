import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var currentState: TrackpadSettingState = .unknown
    @Published private(set) var detailMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var hasAccessibilityPermission = AccessibilityPermissionHelper.hasAccessibilityPermission(prompt: false)

    private let service: TrackpadAutomationService
    private var hasLoadedInitialStatus = false

    init(service: TrackpadAutomationService = TrackpadAutomationService()) {
        self.service = service
    }

    var toggleValue: Bool {
        currentState == .enabled
    }

    var statusText: String {
        currentState.displayName
    }

    var statusColor: Color {
        currentState.color
    }

    func refreshIfNeeded() {
        guard !hasLoadedInitialStatus else {
            return
        }

        hasLoadedInitialStatus = true
        refreshAccessibilityPermissionStatus()
        refresh()
    }

    func refresh() {
        refreshAccessibilityPermissionStatus()
        runOperation {
            try $0.readStatus()
        }
    }

    func setTrackpadIgnoreEnabled(_ enabled: Bool) {
        refreshAccessibilityPermissionStatus()
        runOperation {
            try $0.setIgnoreTrackpadEnabled(enabled)
        }
    }

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = AccessibilityPermissionHelper.hasAccessibilityPermission(prompt: true)
        if !hasAccessibilityPermission {
            AccessibilityPermissionHelper.openAccessibilitySettings()
        }
    }

    private func refreshAccessibilityPermissionStatus() {
        hasAccessibilityPermission = AccessibilityPermissionHelper.hasAccessibilityPermission(prompt: false)
    }

    private func runOperation(_ operation: @escaping (TrackpadAutomationService) throws -> TrackpadAutomationResult) {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil

        Task {
            do {
                let service = self.service
                let result = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            continuation.resume(returning: try operation(service))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                apply(result)
            } catch {
                detailMessage = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            isBusy = false
        }
    }

    private func apply(_ result: TrackpadAutomationResult) {
        currentState = result.state
        detailMessage = result.detailMessage
        errorMessage = nil
    }
}

private extension TrackpadSettingState {
    var color: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .secondary
        case .unknown:
            return .orange
        }
    }
}
