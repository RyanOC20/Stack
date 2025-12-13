import XCTest
@testable import Stack

final class SupabaseErrorMapperTests: XCTestCase {
    func testMapsSupabaseErrorResponseWithStatus() {
        let error = SupabaseErrorResponse(
            message: "Forbidden",
            error: "forbidden",
            errorDescription: nil,
            status: 403,
            rawBody: "raw"
        )

        let mapped = SupabaseErrorMapper.map(error)
        XCTAssertEqual(mapped.message, "Forbidden (status: 403)")
        XCTAssertEqual(mapped.kind, .network)
    }

    func testMapsMissingSessionToFriendlyMessage() {
        let mapped = SupabaseErrorMapper.map(SupabaseClient.ClientError.missingSession)
        XCTAssertEqual(mapped.message, "Please sign in to continue.")
    }

    func testMapsGenericError() {
        struct Sample: Error {}
        let mapped = SupabaseErrorMapper.map(Sample())
        XCTAssertEqual(mapped.message, Sample().localizedDescription)
    }
}
