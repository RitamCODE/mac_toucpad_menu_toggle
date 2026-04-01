import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trackpad Control")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ignore built-in trackpad when mouse is present")
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.isBusy {
                        Text("Applying...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.toggleValue },
                        set: { viewModel.setTrackpadIgnoreEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            HStack {
                Text("Status")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.statusText)
                    .foregroundStyle(viewModel.statusColor)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Accessibility")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.hasAccessibilityPermission ? "Granted" : "Required")
                    .foregroundStyle(viewModel.hasAccessibilityPermission ? .green : .orange)
                    .fontWeight(.semibold)
            }

            if !viewModel.hasAccessibilityPermission {
                Button("Grant Accessibility Access") {
                    viewModel.requestAccessibilityPermission()
                }
            }

            if let detailMessage = viewModel.detailMessage, !detailMessage.isEmpty {
                Text(detailMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Refresh Status") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r")
                .disabled(viewModel.isBusy)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 340)
        .task {
            viewModel.refreshIfNeeded()
        }
    }
}
