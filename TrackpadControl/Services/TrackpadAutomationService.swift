import Foundation

enum TrackpadSettingState: Equatable {
    case enabled
    case disabled
    case unknown

    var displayName: String {
        switch self {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .unknown:
            return "Unknown"
        }
    }
}

struct TrackpadAutomationResult {
    let state: TrackpadSettingState
    let detailMessage: String?
}

enum TrackpadAutomationError: LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case accessibilityPermissionRequired
    case uiScriptingFailed(String)

    var errorDescription: String? {
        switch self {
        case .readFailed(let message):
            return message
        case .writeFailed(let message):
            return message
        case .accessibilityPermissionRequired:
            return "System Settings UI scripting needs Accessibility access. Grant permission to the app and try again."
        case .uiScriptingFailed(let message):
            return message
        }
    }
}

final class TrackpadAutomationService: @unchecked Sendable {
    private let runner: ProcessRunner
    private let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]
    private let key = "USBMouseStopsTrackpad"
    private let checkboxLabel = "Ignore built-in trackpad when mouse or wireless trackpad is present"

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func readStatus() throws -> TrackpadAutomationResult {
        try readStatusSynchronously()
    }

    func setIgnoreTrackpadEnabled(_ enabled: Bool) throws -> TrackpadAutomationResult {
        try setIgnoreTrackpadEnabledSynchronously(enabled)
    }

    private func readStatusSynchronously() throws -> TrackpadAutomationResult {
        var discoveredStates: [String: Bool] = [:]

        for domain in domains {
            let output = try runner.run(executablePath: "/usr/bin/defaults", arguments: ["read", domain, key])
            guard output.terminationStatus == 0 else {
                continue
            }

            if let value = parseBoolean(from: output.standardOutput) {
                discoveredStates[domain] = value
            }
        }

        if discoveredStates.isEmpty {
            return TrackpadAutomationResult(
                state: .unknown,
                detailMessage: "Unable to read \(key) from the expected trackpad preference domains."
            )
        }

        let distinctValues = Set(discoveredStates.values)
        if distinctValues.count > 1 {
            let detail = discoveredStates
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key): \($0.value ? "1" : "0")" }
                .joined(separator: " | ")

            return TrackpadAutomationResult(
                state: .unknown,
                detailMessage: "Preference domains disagree. \(detail)"
            )
        }

        let enabled = distinctValues.first ?? false
        let detail = discoveredStates
            .sorted(by: { $0.key < $1.key })
            .map(\.key)
            .joined(separator: ", ")

        return TrackpadAutomationResult(
            state: enabled ? .enabled : .disabled,
            detailMessage: "Synced via \(detail)."
        )
    }

    private func setIgnoreTrackpadEnabledSynchronously(_ enabled: Bool) throws -> TrackpadAutomationResult {
        let writeResult = try runPreferenceWriteScript(enabled: enabled)
        guard writeResult.terminationStatus == 0 else {
            throw TrackpadAutomationError.writeFailed(
                "Failed to update the trackpad setting. \(nonEmptyMessage(from: writeResult) ?? "The preference script returned an error.")"
            )
        }

        let initialStatus = try readStatusSynchronously()
        let expectedState: TrackpadSettingState = enabled ? .enabled : .disabled

        if !AccessibilityPermissionHelper.hasAccessibilityPermission(prompt: false) {
            if !AccessibilityPermissionHelper.hasAccessibilityPermission(prompt: true) {
                AccessibilityPermissionHelper.openAccessibilitySettings()

                return TrackpadAutomationResult(
                    state: initialStatus.state,
                    detailMessage: [
                        initialStatus.detailMessage,
                        "Preference updated, but Accessibility permission is still needed to click the real System Settings checkbox on this Mac."
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")
                )
            }
        }

        let fallbackResult = try runUIScriptingFallback(enabled: enabled)
        guard fallbackResult.terminationStatus == 0 else {
            throw TrackpadAutomationError.uiScriptingFailed(
                "The preference was written, but System Settings UI scripting did not complete. \(nonEmptyMessage(from: fallbackResult) ?? "Adjust the fallback script for this macOS version.")"
            )
        }

        let reloadedStatus = try readStatusSynchronously()
        return TrackpadAutomationResult(
            state: reloadedStatus.state == .unknown ? expectedState : reloadedStatus.state,
            detailMessage: [
                "Preference updated and System Settings checkbox automation ran.",
                reloadedStatus.detailMessage
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        )
    }

    private func runPreferenceWriteScript(enabled: Bool) throws -> ProcessOutput {
        let desiredValue = enabled ? "true" : "false"
        let domainList = domains.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        set desiredValue to "\(desiredValue)"
        repeat with domainName in {\(domainList)}
            do shell script "/usr/bin/defaults write " & quoted form of domainName & " \(key) -bool " & desiredValue
        end repeat
        try
            do shell script "/usr/bin/killall cfprefsd"
        end try
        return "ok"
        """

        return try runner.run(executablePath: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func runUIScriptingFallback(enabled: Bool) throws -> ProcessOutput {
        let desiredValue = enabled ? "1" : "0"
        let script = """
        set checkboxTitle to "\(checkboxLabel)"
        set desiredValue to \(desiredValue)

        tell application "System Settings"
            activate
            reveal anchor "AX_ALT_MOUSE_BUTTONS" of pane id "com.apple.Accessibility-Settings.extension"
        end tell

        delay 1.0

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                set targetCheckbox to missing value
                repeat until exists window "Pointer Control"
                    delay 0.2
                end repeat

                delay 0.6

                try
                    set targetCheckbox to checkbox checkboxTitle of group 1 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window "Pointer Control"
                end try

                if targetCheckbox is missing value then
                    try
                        set targetCheckbox to checkbox checkboxTitle of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "Pointer Control"
                    end try
                end if

                if targetCheckbox is missing value then
                    set allElements to entire contents of window "Pointer Control"

                    repeat with elementRef in allElements
                        try
                            if role of elementRef is "AXCheckBox" and name of elementRef is checkboxTitle then
                                set targetCheckbox to elementRef
                                exit repeat
                            end if
                        end try
                    end repeat
                end if

                if targetCheckbox is missing value then
                    error "Could not find the checkbox named '" & checkboxTitle & "'. macOS may have changed the Settings layout or label."
                end if

                if value of targetCheckbox is not desiredValue then
                    tell targetCheckbox to perform action "AXPress"
                    delay 0.4
                end if
            end tell
        end tell
        """

        return try runner.run(executablePath: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func parseBoolean(from rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }

    private func nonEmptyMessage(from output: ProcessOutput) -> String? {
        let candidates = [output.standardError, output.standardOutput]
        return candidates.first(where: { !$0.isEmpty })
    }
}
