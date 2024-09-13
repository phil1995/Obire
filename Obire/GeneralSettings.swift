import SwiftUI

struct GeneralSettings: View {
    let appState: AppState
    
    var body: some View {
        VStack {
            if let hasCalendarAccess = appState.hasCalendarAccess {
                if hasCalendarAccess {
                    HStack {
                        List {
                            Section("Calendars") {
                                ForEach(appState.calendars, id: \.sourceIdentifier) { calendar in
                                    Button(action: {
                                        appState.tappedOnCalendar(calendar)
                                    }, label: {
                                        HStack {
                                            Text(calendar.title)
                                            Spacer()
                                            if appState.selectedCalendars.contains(calendar.sourceIdentifier) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                        
                                        .contentShape(Rectangle())
                                    })
                                    .buttonStyle(.plain)
                                }
                            }
                            
                        }.listStyle(.plain)
                        Spacer()
                        List {
                            Section("Upcoming Event") {
                                if let upcomingEvent = appState.upcomingEvent {
                                    VStack {
                                        HStack {
                                            Text("Title:")
                                            Text(upcomingEvent.title)
                                            Spacer()
                                        }
                                        HStack {
                                            Text("Start Date:")
                                            Text(upcomingEvent.startDate, format: .dateTime)
                                            Spacer()
                                        }
                                        HStack {
                                            Text("End Date:")
                                            Text(upcomingEvent.endDate, format: .dateTime)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                } else {
                                    ContentUnavailableView("No upcoming event", systemImage: "info.circle")
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    
                } else {
                    Button("Connect calendar") {
                        Task {
                            do { try await appState.requestCalendarAccess() }
                            catch {
                                print(error)
                            }
                        }
                    }
                }
                
            } else {
                ProgressView()
            }
        }
        .padding()
        .task { appState.fetchCalendarAccess() }
    }
}

#Preview {
    GeneralSettings(appState: .init(modelContext: .preview) )
        .frame(width: 400, height: 400)
}
