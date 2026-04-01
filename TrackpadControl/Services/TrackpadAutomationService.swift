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

    var errorDescription: String? {
        switch self {
        case .readFailed(let message):
            return message
        case .writeFailed(let message):
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

        let expectedState: TrackpadSettingState = enabled ? .enabled : .disabled
        let reloadedStatus = try readStatusSynchronously()
        let resolvedState = reloadedStatus.state == .unknown ? expectedState : reloadedStatus.state
        let detailPrefix: String

        if reloadedStatus.state == .unknown {
            detailPrefix = "Preference updated. Exact readback is best effort on this macOS version."
        } else if reloadedStatus.state == expectedState {
            detailPrefix = "Preference updated."
        } else {
            detailPrefix = "Preference write completed, but macOS reported a different value after refresh."
        }

        return TrackpadAutomationResult(
            state: resolvedState,
            detailMessage: [
                detailPrefix,
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
