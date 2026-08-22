import Foundation

enum InstalledAppLocationKind: Equatable {
    case applications
    case diskImage
    case other
}

enum InstalledAppLocation {
    static func classify(_ path: String, home: String = NSHomeDirectory()) -> InstalledAppLocationKind {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized.hasPrefix("/Volumes/") {
            return .diskImage
        }
        if standardized.hasPrefix("/Applications/") {
            return .applications
        }
        let homeApps = URL(fileURLWithPath: home).appendingPathComponent("Applications").standardizedFileURL.path
        if standardized == homeApps || standardized.hasPrefix(homeApps + "/") {
            return .applications
        }
        return .other
    }

    static var current: InstalledAppLocationKind {
        classify(Bundle.main.bundlePath)
    }

    static var applicationsCopyURL: URL {
        URL(fileURLWithPath: "/Applications/Notepad.app")
    }
}
