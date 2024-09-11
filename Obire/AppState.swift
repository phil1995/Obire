import Foundation
import EventKit
import AppKit

@MainActor
@Observable
final class AppState {
    private let eventStore = EKEventStore()
    var hasCalendarAccess: Bool?
    
    var selectedCalendars: Set<EKSource> = []
    var calendars: [EKSource] { eventStore.sources }
    var upcomingEvent: EKEvent?
    var showsFullScreenOverlay: Bool { fullSizeOverlayController != nil }
    
    private var calendarObservationTask: Task<Void, Never>?
    
    private var fullSizeOverlayController: NSWindowController?
    
    
    func wantsToShowFullScreenOverlay() {
        fullSizeOverlayController = FullSizeOverlayController(rootView: FullSizeContentView(appState: self))
        fullSizeOverlayController?.showWindow(nil)
    }
    
    func wantsToCloseFullScreenOverlay() {
        fullSizeOverlayController?.close()
    }
    
    @discardableResult
    func requestCalendarAccess() async throws -> Bool {
        let hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
        self.hasCalendarAccess = hasCalendarAccess
        return hasCalendarAccess
    }
    
    func fetchCalendarAccess() {
        hasCalendarAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    func tappedOnCalendar(_ calendar: EKSource) {
        let result = selectedCalendars.insert(calendar)
        defer {
            refreshUpcomingEvent()
        }
        guard result.inserted else {
            selectedCalendars.remove(calendar)
            return
        }
    }
    
    func stopCalendarEventsObservation() { 
        calendarObservationTask?.cancel()
    }
    
    func startCalendarEventsObservation() {
        calendarObservationTask?.cancel()
        calendarObservationTask = Task {
            let newDay = NotificationCenter.default.publisher(for: .NSCalendarDayChanged).map(\.name)
            let eventStoreChanged = NotificationCenter.default.publisher(for: .EKEventStoreChanged).map(\.name)
            for await _ in newDay.merge(with: eventStoreChanged).values {
                refreshUpcomingEvent()
            }
        }
    }
    
    func refreshUpcomingEvent() {
        let events = fetchCalendarEvents()
        self.upcomingEvent = events.sorted(by: { $0.startDate < $1.startDate }).first
    }
    
    private func fetchCalendarEvents() -> [EKEvent] {
        let calendars = selectedCalendars.flatMap { $0.calendars(for: .event) }
        guard !calendars.isEmpty else {
            return []
        }
        
        // Create the end date components.
        var oneMonthFromNowComponents = DateComponents()
        oneMonthFromNowComponents.month = 1
        guard let oneMonthFromNow = Calendar.current.date(byAdding: oneMonthFromNowComponents, to: Date(), wrappingComponents: false) else {
            return []
        }
        
        // Create the predicate from the event store's instance method.
        let predicate = eventStore.predicateForEvents(withStart: Date(), end: oneMonthFromNow, calendars: calendars)

        // Fetch all events that match the predicate.
        return eventStore.events(matching: predicate)
    }
}
