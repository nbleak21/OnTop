import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SMC.shared.close()
    }
}
