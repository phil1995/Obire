import SwiftUI
import SwiftData

@MainActor
@main
struct ObireApp: App {
    let container: ModelContainer
    @State private var appState: AppState
    
    
    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: SelectedCalendar.self)
        } catch {
            fatalError("Failed to created ModelContainer for SelectedCalendar")
        }
        self.container = container
        self.appState = AppState(modelContext: container.mainContext)
    }
    
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
        .modelContainer(for: [
            SelectedCalendar.self
        ])
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

struct FullSizeContentView: View {
    @Environment(\.openURL) private var openURL
    
    let title: String
    let conferenceURL: URL?
    let startDate: Date
    let endDate: Date
    let appState: AppState
        
    var body: some View {
        VStack(spacing: 64) {
            Text(title)
                .font(.system(size: 64))
            
            CountDownTimer(startDate: startDate)
                .font(.title)
            Text(startDate...endDate)
            
            
            HStack {
                Button("Dismiss") {
                    appState.wantsToCloseFullScreenOverlay()
                }
                .buttonStyle(.bordered)
                
                if let conferenceURL {
                    Button("Join") {
                        openURL(conferenceURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x267871),
                    Color(hex: 0x136A8A)
                ]),
                startPoint: .trailing,
                endPoint: .leading
            )
        )
    }
}

struct CountDownTimer: View {
    let startDate: Date
    var now: Date = .now
    private var isInPast: Bool { startDate < now }
    
    var body: some View {
        HStack {
            Text(isInPast ? "Since" : "In")
            Text(startDate, style: .timer)
                .foregroundStyle(isInPast ? .red : .primary)
        }
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

#Preview {
    FullSizeContentView(
        title: "Example Meeting",
        conferenceURL: .init(string: "example.com"),
        startDate: .init(timeIntervalSince1970: 39_600),
        endDate: .init(timeIntervalSince1970: 41_400),
        appState: .init(modelContext: .preview)
    )
}
