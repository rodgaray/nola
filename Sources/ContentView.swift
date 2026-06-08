import SwiftUI

// MARK: - Display helpers

extension DownloadItem.State {
    var label: String {
        switch self {
        case .queued:      return "En cola"
        case .downloading: return "Descargando"
        case .paused:      return "Pausada"
        case .completed:   return "Completada"
        case .failed:      return "Error"
        }
    }
    var systemImage: String {
        switch self {
        case .queued:      return "circle"
        case .downloading: return "arrow.down.circle.fill"
        case .paused:      return "pause.circle.fill"
        case .completed:   return "checkmark.circle.fill"
        case .failed:      return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .queued:      return .secondary
        case .downloading: return .accentColor
        case .paused:      return .orange
        case .completed:   return .green
        case .failed:      return .red
        }
    }
}

// MARK: - Item row

struct ItemRow: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: item.state.systemImage)
                    .foregroundStyle(item.state.color)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14)
                Text(item.url)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                actionButtons
            }
            if (item.state == .downloading || item.state == .paused) && item.progress > 0 {
                HStack(spacing: 6) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(item.state == .paused ? .orange : .accentColor)
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if item.state == .downloading {
            HStack(spacing: 0) {
                iconBtn("pause.fill",     action: onPause,  help: "Pausar")
                iconBtn("xmark",          action: onCancel, help: "Cancelar y borrar .part", tint: .red)
            }
        } else if item.state == .paused {
            HStack(spacing: 0) {
                iconBtn("play.fill",      action: onResume, help: "Reanudar", tint: .accentColor)
                iconBtn("xmark",          action: onCancel, help: "Cancelar y borrar .part", tint: .red)
            }
        } else if item.state == .queued {
            iconBtn("xmark",              action: onCancel, help: "Quitar de la cola", tint: .secondary)
        } else if item.state == .completed {
            iconBtn("xmark",              action: onRemove, help: "Limpiar", tint: .secondary)
        } else {
            HStack(spacing: 0) {
                iconBtn("arrow.clockwise", action: onRetry, help: "Reintentar")
                iconBtn("xmark",           action: onRemove, help: "Quitar", tint: .secondary)
            }
        }
    }

    private func iconBtn(_ icon: String, action: @escaping () -> Void, help: String, tint: Color = .primary) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(tint)
        .help(help)
    }
}

// MARK: - Main panel

struct ContentView: View {
    @StateObject private var manager = DownloadManager()

    @State private var urlsText      = ""
    @State private var mode          = MediaMode.video
    @State private var videoQuality  = VideoQuality.bestMp4
    @State private var audioFormat   = AudioFormat.mp3
    @State private var isLogExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            inputSection
            formatRow
            actionRow
            if !manager.items.isEmpty {
                Divider().opacity(0.5)
                queueSection
            }
            if !manager.log.isEmpty {
                Divider().opacity(0.5)
                logSection
            }
            Divider().opacity(0.4)
            footerBar
        }
        .padding(16)
        .frame(width: 400)
        .background(.ultraThinMaterial)
    }

    // MARK: URL input

    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $urlsText)
                .font(.system(.footnote, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            if urlsText.isEmpty {
                Text("Pegá URLs aquí, una por línea…")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
                    .padding(.leading, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 72)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    // MARK: Format pickers

    private var formatRow: some View {
        VStack(spacing: 8) {
            Picker("", selection: $mode) {
                Text("Video").tag(MediaMode.video)
                Text("Audio").tag(MediaMode.audio)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .video {
                Picker("Calidad", selection: $videoQuality) {
                    ForEach(VideoQuality.allCases) { q in Text(q.rawValue).tag(q) }
                }
                .pickerStyle(.menu)
            } else {
                Picker("Formato", selection: $audioFormat) {
                    ForEach(AudioFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: Download button

    private var actionRow: some View {
        Button(action: startDownload) {
            Label("Download", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(urlsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .keyboardShortcut(.return, modifiers: .command)
    }

    // MARK: Queue list

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cola — \(manager.items.count) \(manager.items.count == 1 ? "ítem" : "ítems")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if manager.items.allSatisfy({ $0.state == .completed || $0.state == .failed }) {
                    Button("Limpiar todo") { manager.clearFinished() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(manager.items) { item in
                        ItemRow(
                            item: item,
                            onPause:  { manager.pause() },
                            onResume: { manager.resume(id: item.id) },
                            onCancel: { manager.cancel(id: item.id) },
                            onRemove: { manager.remove(id: item.id) },
                            onRetry:  { manager.retry(id: item.id) }
                        )
                        if item.id != manager.items.last?.id {
                            Divider().padding(.leading, 10).opacity(0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Log

    private var logSection: some View {
        DisclosureGroup(isExpanded: $isLogExpanded) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(manager.log)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(6)
                        .id("log")
                }
                .frame(height: 120)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: manager.log) { _, _ in
                    proxy.scrollTo("log", anchor: .bottom)
                }
            }
        } label: {
            Text("Log")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Footer

    private var footerBar: some View {
        HStack {
            Spacer()
            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Preferencias")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Salir de NoLa")
        }
    }

    // MARK: Actions

    private func startDownload() {
        let urls = urlsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !urls.isEmpty else { return }

        // Respect custom format overrides from Settings
        let customVideo = UserDefaults.standard.string(forKey: "customFormatVideo") ?? ""
        let customAudio = UserDefaults.standard.string(forKey: "customFormatAudio") ?? ""

        let opts: DownloadOptions
        if mode == .video {
            let fmt = customVideo.isEmpty ? videoQuality.formatString : customVideo
            opts = DownloadOptions(format: fmt)
        } else {
            let fmt = customAudio.isEmpty ? audioFormat.formatString : customAudio
            opts = DownloadOptions(format: fmt, extraArgs: customAudio.isEmpty ? audioFormat.extraArgs : [])
        }

        for url in urls { manager.download(url: url, options: opts) }
        urlsText = ""
        isLogExpanded = true
    }
}
