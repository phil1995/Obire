import Foundation
import EventKit
import AppKit
import SwiftData
import OSLog

let logger = Logger(subsystem: "de.pscoding.obire", category: "AppState")


@MainActor
@Observable
final class AppState {
    private let modelContext: ModelContext
    private let eventStore = EKEventStore()
    var hasCalendarAccess: Bool?
    
    var selectedCalendars: Set<String> = []
    var calendars: [EKSource] { eventStore.sources }
    var upcomingEvent: EKEvent?
    var showsFullScreenOverlay: Bool { fullSizeOverlayController != nil }
    
    private var calendarObservationTask: Task<Void, Never>?
    private var showEventTimer: Timer?
    
    private var fullSizeOverlayController: NSWindowController?
    
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let calendars: [SelectedCalendar]
        do {
            calendars = try modelContext.fetch(FetchDescriptor<SelectedCalendar>())
        } catch {
            print("Failed to fetch SelectedCalendar")
            calendars = []
        }
        self.selectedCalendars = Set(calendars.map(\.sourceIdentifier))
    }
    
    func wantsToShowFullScreenOverlay() {
        guard let upcomingEvent else { return }
        fullSizeOverlayController = FullSizeOverlayController(
            rootView: FullSizeContentView(
                title: upcomingEvent.title,
                conferenceURL: upcomingEvent.conferenceURL,
                startDate: upcomingEvent.startDate,
                endDate: upcomingEvent.endDate,
                appState: self
            )
        )
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
        let result = selectedCalendars.insert(calendar.sourceIdentifier)
        defer {
            try? modelContext.save()
            refreshUpcomingEvent()
        }
        guard result.inserted else {
            let sourceIdentifier = calendar.sourceIdentifier
            let predicate = #Predicate { (selectedCalendar: SelectedCalendar) in
                selectedCalendar.sourceIdentifier == sourceIdentifier
            }
            do {
                try modelContext.delete(model: SelectedCalendar.self, where: predicate)
            } catch {
                logger.error("Can't delete calendar: \(error.localizedDescription, privacy: .public)")
            }
            selectedCalendars.remove(calendar.sourceIdentifier)
            return
        }
        let entry = SelectedCalendar(sourceIdentifier: calendar.sourceIdentifier)
        modelContext.insert(entry)
    }
    
    func stopCalendarEventsObservation() { 
        calendarObservationTask?.cancel()
    }
    
    func startCalendarEventsObservation() {
        calendarObservationTask?.cancel()
        refreshUpcomingEvent()
        calendarObservationTask = Task {
            let newDay = NotificationCenter.default.publisher(for: .NSCalendarDayChanged).map(\.name)
            let eventStoreChanged = NotificationCenter.default.publisher(for: .EKEventStoreChanged).map(\.name)
            for await _ in newDay.merge(with: eventStoreChanged).values {
                refreshUpcomingEvent()
            }
        }
    }
    
    func refreshUpcomingEvent() {
        logger.debug("Refresh upcoming event")
        let events = fetchCalendarEvents()
        let currentUpcomingEvent = self.upcomingEvent
        self.upcomingEvent = events.sorted(by: { $0.startDate < $1.startDate }).first(where: { $0.startDate >= .now })
        guard currentUpcomingEvent != self.upcomingEvent else { return }
        guard let upcomingEvent else { return }
        logger.debug("Invalidate old timer")
        showEventTimer?.invalidate()
        guard let fireAt = Calendar.current.date(byAdding: .minute, value: -1, to: upcomingEvent.startDate) else {
            logger.error("Failed to create fire date")
            return
        }
        let timer = Timer(fire: fireAt, interval: 0, repeats: false) { [weak self] timer in
            timer.invalidate()
            logger.debug("Timer fired")
            Task { @MainActor [weak self] in
                self?.showEventTimer = nil
                self?.wantsToShowFullScreenOverlay()
            }
        }
        RunLoop.main.add(timer, forMode: .default)
        logger.debug("Started new timer which fires at: \(fireAt, privacy: .public)")
        showEventTimer = timer
    }
    
    private func fetchCalendarEvents() -> [EKEvent] {
        let calendars = calendars.filter { selectedCalendars.contains($0.sourceIdentifier) }.flatMap { $0.calendars(for: .event) }
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

extension AppState {
    static var preview: AppState { .init(modelContext: .preview) }
}
