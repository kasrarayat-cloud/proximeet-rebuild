import SwiftUI

@main
struct ProximeetApp: App {
    @State private var session: DemoSession
    private let reduceMotionPreview: Bool

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        _session = State(initialValue: DebugLaunch.session(arguments: arguments) ?? DemoSession())
        reduceMotionPreview = DebugLaunch.prefersReducedMotionPreview(arguments: arguments)
        #else
        _session = State(initialValue: DemoSession())
        reduceMotionPreview = false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.prefersReducedMotionPreview, reduceMotionPreview)
        }
    }
}
