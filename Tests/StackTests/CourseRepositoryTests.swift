import XCTest
@testable import Stack

final class CourseRepositoryTests: XCTestCase {
    private let repository = CourseRepository()

    func testAvailableCoursesAreUniqueAndSorted() {
        let assignments = [
            Assignment(status: .notStarted, name: "One", course: "Math 101", type: .homework, dueAt: Date()),
            Assignment(status: .notStarted, name: "Two", course: "math 101", type: .essay, dueAt: Date()),
            Assignment(status: .notStarted, name: "Three", course: "  ", type: .exam, dueAt: Date()),
            Assignment(status: .notStarted, name: "Four", course: "Anthro 202", type: .quiz, dueAt: Date())
        ]

        let courses = repository.availableCourses(from: assignments)

        XCTAssertEqual(courses.count, 3)
        XCTAssertEqual(courses.first, "Anthro 202")
        XCTAssertTrue(courses.contains("Math 101"))
        XCTAssertTrue(courses.contains("math 101"))
    }
}
