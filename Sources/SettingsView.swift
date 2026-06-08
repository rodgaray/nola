import SwiftUI

struct SettingsView: View {
    @AppStorage("downloadDirectoryPath") private var downloadDirectoryPath: String = ""
    @AppStorage("customFormatVideo")     private var customFormatVideo: String = ""
    @AppStorage("customFormatAudio")     private var customFormatAudio: String = ""

    private var displayPath: String {
        downloadDirectoryPath.isEmpty
            ? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path(percentEncoded: false)
            : downloadDirectoryPath
    }

    var body: some View {
        Form {
            Section("Descarga") {
                LabeledContent("Carpeta") {
                    HStack {
                        Text(displayPath)
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Elegir…") { pickFolder() }
                            .buttonStyle(.bordered)
                    }
                }
                Button("Restablecer por defecto") {
                    downloadDirectoryPath = ""
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .font(.callout)
            }

            Section {
                LabeledContent("Video") {
                    TextField("Ej: bestvideo[ext=mp4]+bestaudio/best", text: $customFormatVideo)
                        .font(.system(.footnote, design: .monospaced))
                }
                LabeledContent("Audio") {
                    TextField("Ej: bestaudio/best", text: $customFormatAudio)
                        .font(.system(.footnote, design: .monospaced))
                }
                Text("Vacío = usar los presets del panel principal. Se pasa directo a yt-dlp con -f.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Formato personalizado (yt-dlp)")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .frame(minHeight: 280)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Elegir carpeta de descarga"
        panel.prompt = "Elegir"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        downloadDirectoryPath = url.path(percentEncoded: false)
    }
}
