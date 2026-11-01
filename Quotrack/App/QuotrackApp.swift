import AppKit

/// AppKit entry point. The status item, floating panel, and Settings window
/// are all created by `AppDelegate`; there is no SwiftUI scene, so a
/// placeholder `Settings` scene cannot open an empty window on ⌘,.
@main
enum QuotrackMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
