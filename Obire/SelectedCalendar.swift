import Foundation
import SwiftData

@Model
final class SelectedCalendar {
    @Attribute(.unique) var sourceIdentifier: String
    
    init(sourceIdentifier: String) {
        self.sourceIdentifier = sourceIdentifier
    }
}

extension ModelContext {
    static var preview: ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SelectedCalendar.self, configurations: config)
        return ModelContext(container)
    }
}
