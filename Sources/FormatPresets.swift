import Foundation

enum MediaMode: Equatable {
    case video, audio
}

enum VideoQuality: String, CaseIterable, Identifiable, Equatable {
    case bestMp4 = "Mejor MP4"
    case p1080   = "1080p"
    case p720    = "720p"

    var id: String { rawValue }

    var formatString: String {
        switch self {
        case .bestMp4:
            return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        case .p1080:
            return "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best"
        case .p720:
            return "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best"
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable, Equatable {
    case mp3  = "MP3 320k"
    case m4a  = "M4A"
    case flac = "FLAC"

    var id: String { rawValue }

    var formatString: String {
        switch self {
        case .mp3, .flac: return "bestaudio/best"
        case .m4a:        return "bestaudio[ext=m4a]/bestaudio/best"
        }
    }

    var extraArgs: [String] {
        switch self {
        case .mp3:  return ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        case .m4a:  return ["-x", "--audio-format", "m4a"]
        case .flac: return ["-x", "--audio-format", "flac"]
        }
    }
}
