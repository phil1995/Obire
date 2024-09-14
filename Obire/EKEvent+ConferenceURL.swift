import Foundation
import EventKit

extension EKEvent {
    /// The conference url corresponding to the event.
    ///
    /// According to the linked StackOverflow Answer the conference url is either:
    /// 1. Inside the location
    /// 2. Inside the notes
    /// 3. Set as the event.url
    ///
    /// Source: https://stackoverflow.com/a/78683088
    var conferenceURL: URL? {
        if let url {
            return url
        }
        
        if let detectedNotesURL = notes?.detectedURL {
            return detectedNotesURL
        }
        
        if let detectedLocationURL = location?.detectedURL {
            return detectedLocationURL
        }
        
        return nil
    }
}

private extension String {
    var detectedURL: URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) ?? []
        
        for match in matches {
            if let url = match.url {
                return url
            }
        }
        return nil
    }
}
