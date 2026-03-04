import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Show prominent overlay", isOn: $settings.showProminentOverlay)
                Text("Display a full-screen overlay when a message arrives. If disabled, only the menu bar badge is shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Follow Focus modes", isOn: $settings.followFocusModes)
                Text("By default, messages appear even during Focus/Do Not Disturb. Enable this to suppress overlays during Focus modes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                HStack {
                    Text("Message Bucket folder")
                    Spacer()
                    Text(settings.basePath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Change…") {
                        chooseFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.basePath = url.path
        }
    }
}
