import Foundation
import CoreServices

enum LaunchServicesRegistration {
    @discardableResult
    static func registerPreferredCopy(
        runningPath: String = Bundle.main.bundlePath,
        applicationsCopy: URL = InstalledAppLocation.applicationsCopyURL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        register: (URL) -> Void = { LSRegisterURL($0 as CFURL, true) }
    ) -> URL? {
        let kind = InstalledAppLocation.classify(runningPath)
        let target: URL
        switch kind {
        case .applications:
            target = URL(fileURLWithPath: runningPath)
        case .diskImage, .other:
            guard fileExists(applicationsCopy) else { return nil }
            target = applicationsCopy
        }
        register(target)
        return target
    }
}
