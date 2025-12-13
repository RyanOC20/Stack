import XCTest
@testable import Stack

final class LocalCacheTests: XCTestCase {
    func testSubscriptStoresAndRetrievesValues() {
        let cache = LocalCache<String, Int>()
        XCTAssertNil(cache["missing"])

        cache["answer"] = 42
        XCTAssertEqual(cache["answer"], 42)

        cache["answer"] = 100
        XCTAssertEqual(cache["answer"], 100)
    }
}
