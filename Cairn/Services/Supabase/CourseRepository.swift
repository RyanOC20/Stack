import Foundation

protocol CourseRepositoryProviding {
    func availableCourses(from assignments: [Assignment]) -> [String]
}

struct CourseRepository: CourseRepositoryProviding {
    func availableCourses(from assignments: [Assignment]) -> [String] {
        let unique = Set(assignments.map { $0.course }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
