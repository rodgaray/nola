import Foundation

struct DownloadOptions: Codable {
    var outputDirectory: URL
    var format: String
    var extraArgs: [String]

    init(
        outputDirectory: URL = {
            if let p = UserDefaults.standard.string(forKey: "downloadDirectoryPath"), !p.isEmpty {
                return URL(fileURLWithPath: p)
            }
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        }(),
        format: String = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        extraArgs: [String] = []
    ) {
        self.outputDirectory = outputDirectory
        self.format = format
        self.extraArgs = extraArgs
    }
}

// @MainActor guarantees every @Published mutation happens on the main actor,
// so SwiftUI always sees consistent state and re-renders immediately.
@MainActor
final class DownloadManager: ObservableObject {

    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var log: String = ""

    private enum TerminationReason { case natural, paused, cancelled }

    private var isProcessing = false
    private var currentProcess: Process?
    private var currentItemID: UUID?
    private var terminationReason: TerminationReason = .natural
    private var detectedDestinations: [String] = []

    // Line-assembly buffers — main-actor isolated, reset per download.
    private var outBuf = ""
    private var errBuf = ""

    private let persistence = PersistenceManager()
    private let progressRegex = try! NSRegularExpression(pattern: #"\[download\]\s+([\d.]+)%"#)

    init() {
        var loaded = persistence.load()
        for i in loaded.indices where loaded[i].state == .downloading {
            loaded[i].state = .paused   // app was killed mid-download
        }
        items = loaded
        if items.contains(where: { $0.state == .queued }) {
            processNext()
        }
    }

    // MARK: - Public API

    func download(url: String, options: DownloadOptions = .init()) {
        items.append(DownloadItem(url: url, options: options))
        persistence.save(items)
        if !isProcessing { processNext() }
    }

    func pause() {
        guard isProcessing else { return }
        terminationReason = .paused
        currentProcess?.terminate()
    }

    func resume(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].state == .paused else { return }
        items[idx].state = .queued
        persistence.save(items)
        if !isProcessing { processNext() }
    }

    func cancel(id: UUID) {
        if let item = items.first(where: { $0.id == id }),
           let cid = currentItemID, cid == item.id,
           item.state == .downloading {
            terminationReason = .cancelled
            currentProcess?.terminate()
        } else if let item = items.first(where: { $0.id == id }) {
            deletePartFiles(destinations: item.partFilePaths)
            items.removeAll { $0.id == id }
            persistence.save(items)
        }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persistence.save(items)
    }

    func retry(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].state == .failed else { return }
        items[idx].state = .queued
        items[idx].progress = 0
        items[idx].partFilePaths = []
        persistence.save(items)
        if !isProcessing { processNext() }
    }

    func clearFinished() {
        items.removeAll { $0.state == .completed || $0.state == .failed }
        persistence.save(items)
    }

    // MARK: - Queue

    private func processNext() {
        guard !isProcessing,
              let item = items.first(where: { $0.state == .queued }) else { return }
        isProcessing = true
        // Inherit @MainActor; suspends (releases main thread) while download runs.
        Task {
            await execute(item: item)
            isProcessing = false
            processNext()
        }
    }

    // MARK: - Execution

    private func execute(item: DownloadItem) async {
        currentItemID = item.id
        terminationReason = .natural
        detectedDestinations = []
        outBuf = ""
        errBuf = ""

        updateItem(id: item.id, state: .downloading)
        log = ""
        appendLog("▶ \(item.url)\n")

        let ytdlpPath = resolveBinary("yt-dlp")
        guard FileManager.default.isExecutableFile(atPath: ytdlpPath) else {
            updateItem(id: item.id, state: .failed)
            appendLog("✗ yt-dlp not found at \(ytdlpPath)\n")
            persistence.save(items)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        process.arguments = buildArguments(url: item.url, options: item.options)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        currentProcess = process

        // Bridge Process callbacks → async/await.
        // withCheckedContinuation suspends the main actor so it stays free
        // to process Tasks and render SwiftUI during the download.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in

            // readabilityHandler runs on FileHandle's internal queue (background).
            // We only read raw bytes there; all buffer/state work hops to @MainActor.
            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                let text = String(data: data, encoding: .utf8) ?? ""
                let isEOF = data.isEmpty
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if isEOF {
                        handle.readabilityHandler = nil
                        if !self.outBuf.isEmpty {
                            self.handleOutputLine(self.outBuf, itemID: item.id)
                            self.outBuf = ""
                        }
                        return
                    }
                    self.outBuf += text
                    let (lines, rest) = Self.splitLines(self.outBuf)
                    self.outBuf = rest
                    for line in lines { self.handleOutputLine(line, itemID: item.id) }
                }
            }

            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                let text = String(data: data, encoding: .utf8) ?? ""
                let isEOF = data.isEmpty
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if isEOF {
                        handle.readabilityHandler = nil
                        if !self.errBuf.isEmpty {
                            self.appendLog("[err] \(self.errBuf)\n")
                            self.errBuf = ""
                        }
                        return
                    }
                    self.errBuf += text
                    let (lines, rest) = Self.splitLines(self.errBuf)
                    self.errBuf = rest
                    for line in lines { self.appendLog("[err] \(line)\n") }
                }
            }

            process.terminationHandler = { [weak self] proc in
                let code = proc.terminationStatus
                Task { @MainActor [weak self] in
                    guard let self else { continuation.resume(); return }
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil

                    switch self.terminationReason {
                    case .paused:
                        self.updateItem(id: item.id, state: .paused)
                        self.appendLog("⏸ Paused\n")
                    case .cancelled:
                        self.deletePartFiles(destinations: self.detectedDestinations)
                        self.items.removeAll { $0.id == item.id }
                        self.appendLog("⊘ Cancelled\n")
                    case .natural:
                        if code == 0 {
                            self.updateItem(id: item.id, state: .completed, progress: 1.0)
                            self.appendLog("✓ Completed\n")
                        } else {
                            self.updateItem(id: item.id, state: .failed)
                            self.appendLog("✗ Failed (exit \(code))\n")
                        }
                    }
                    self.persistence.save(self.items)
                    self.currentProcess = nil
                    self.currentItemID = nil
                    continuation.resume()
                }
            }

            // process.run() is synchronous; we're still in the continuation closure
            // on the main actor here, so direct state access is fine.
            do {
                try process.run()
            } catch {
                updateItem(id: item.id, state: .failed)
                appendLog("✗ Launch failed: \(error.localizedDescription)\n")
                persistence.save(items)
                continuation.resume()
            }
        }
    }

    // MARK: - Helpers

    private func updateItem(id: UUID, state: DownloadItem.State, progress: Double? = nil) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].state = state
        if let p = progress { items[idx].progress = p }
    }

    private func handleOutputLine(_ line: String, itemID: UUID) {
        appendLog(line + "\n")

        let range = NSRange(line.startIndex..., in: line)
        if let match = progressRegex.firstMatch(in: line, range: range),
           let r = Range(match.range(at: 1), in: line),
           let pct = Double(line[r]),
           let idx = items.firstIndex(where: { $0.id == itemID }) {
            items[idx].progress = pct / 100.0
        }

        let destPrefix = "[download] Destination: "
        if line.hasPrefix(destPrefix) {
            let path = String(line.dropFirst(destPrefix.count))
            detectedDestinations.append(path)
            if let idx = items.firstIndex(where: { $0.id == itemID }),
               !items[idx].partFilePaths.contains(path) {
                items[idx].partFilePaths.append(path)
            }
        }
    }

    private func appendLog(_ text: String) {
        log += text
    }

    private func deletePartFiles(destinations: [String]) {
        for dest in destinations {
            try? FileManager.default.removeItem(atPath: dest + ".part")
        }
    }

    private func resolveBinary(_ name: String) -> String {
        if let path = Bundle.main.path(forResource: name, ofType: nil),
           FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "/opt/homebrew/bin/\(name)"
    }

    private func buildArguments(url: String, options: DownloadOptions) -> [String] {
        let ffmpegDir = URL(fileURLWithPath: resolveBinary("ffmpeg"))
            .deletingLastPathComponent().path
        let output = options.outputDirectory
            .appendingPathComponent("%(title)s.%(ext)s").path
        var args = ["--newline", "--continue", "-f", options.format,
                    "--ffmpeg-location", ffmpegDir, "-o", output]
        args += options.extraArgs
        args.append(url)
        return args
    }

    private static func splitLines(_ buffer: String) -> ([String], String) {
        var lines: [String] = []
        var current = ""
        for ch in buffer {
            if ch == "\n" || ch == "\r" {
                if !current.isEmpty { lines.append(current) }
                current = ""
            } else {
                current.append(ch)
            }
        }
        return (lines, current)
    }
}
