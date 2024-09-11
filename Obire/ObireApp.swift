import SwiftUI
import SwiftUIIntrospect

@MainActor
@main
struct ObireApp: App {
    @State private var appState = AppState()
    
    
    @State private var foo = false
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }.onChange(of: appState.hasCalendarAccess) { _, hasCalendarAccess in
            if hasCalendarAccess == true {
                appState.startCalendarEventsObservation()
            } else {
                appState.stopCalendarEventsObservation()
            }
        }
        /*
        WindowGroup("Overlay", id: WindowId.overlay) {
            FullSizeOverlay()
        }
        .windowStyle(.hiddenTitleBar)
         */
    }
}

enum WindowId {
    static var overlay = "overlay"
}

struct FullSizeDebugView: View {
    @Environment(\.openWindow) var openWindow
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        Button("Open") {
            appState.wantsToShowFullScreenOverlay()
        }
    }
}

/*
 import SwiftUIIntrospect
/// Breaks animation after the first full screen display
struct FullSizeOverlay: View {
    @State private var closed = false
    
    var body: some View {
        VStack {
            Text("Go to your meeting!")
                .frame(width: 500, height: 100)
            Button("Close") {
                closed = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .introspect(.window, on: .macOS(.v14, .v15)) { window in
            if closed {
                NSApplication.shared.presentationOptions = [] // reset the dock and menu bar
                window.close()
                window.level = .normal
            } else {
                window.styleMask = .borderless
                window.setFrame(window.screen!.frame, display: true)
                window.level = .floating // put window in front of all other windows
                NSApplication.shared.presentationOptions = [.hideDock, .hideMenuBar]
            }
        }
    }
}
 */

struct FullSizeContentView: View {
    let appState: AppState
    
    var body: some View {
        VStack {
            Text("Go to your meeting!")
                .frame(width: 500, height: 100)
            Button("Close") {
                appState.wantsToCloseFullScreenOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}


class FullSizeOverlayController<RootView: View>: NSWindowController {
    convenience init(rootView: RootView) {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = .fullSizeContentView
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            window.setFrame(screenFrame, display: true)
        }
        window.level = .floating // put window in front of all other windows
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenDisallowsTiling]
        self.init(window: window)
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApplication.shared.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
    }
    
    override func close() {
        NSApplication.shared.presentationOptions = []
        super.close()
    }
}
