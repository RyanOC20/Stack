import Foundation

struct Course: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String

    init(title: String) {
        self.id = UUID()
        self.title = title
    }
}
