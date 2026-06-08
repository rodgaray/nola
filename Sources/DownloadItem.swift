import Foundation

struct DownloadItem: Identifiable, Codable {

    enum State: String, Codable, Equatable {
        case queued, downloading, paused, completed, failed
    }

    var id = UUID()
    var url: String
    var options: DownloadOptions
    var state: State = .queued
    var progress: Double = 0.0
    var partFilePaths: [String] = []
    var addedAt: Date = Date()
}

struct PersistenceManager {

    private var queueURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NoLa")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queue.json")
    }

    func save(_ items: [DownloadItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: queueURL, options: .atomic)
    }

    func load() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: queueURL),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else {
            return []
        }
        // Don't restore completed items across sessions
        return items.filter { $0.state != .completed }
    }
}
