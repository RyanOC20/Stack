@testable import Cairn
import Foundation

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
    }
}

final class InMemorySessionStore: SupabaseSessionStore {
    private(set) var storedSession: SupabaseSession?

    init(storedSession: SupabaseSession? = nil) {
        self.storedSession = storedSession
    }

    func loadSession() -> SupabaseSession? {
        storedSession
    }

    func save(_ session: SupabaseSession) {
        storedSession = session
    }

    func clear() {
        storedSession = nil
    }
}

func makeMockURLSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

extension URLRequest {
    /// The request URL, which mock handlers always populate. Falls back to a
    /// throwaway URL so tests never force-unwrap.
    var testURL: URL {
        url ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}

/// Builds an `HTTPURLResponse` for mock request handlers without force-unwrapping.
/// Inputs are always valid in tests, so a nil result is a programmer error.
func makeHTTPResponse(
    for request: URLRequest,
    statusCode: Int,
    headerFields: [String: String]? = nil
) -> HTTPURLResponse {
    guard let response = HTTPURLResponse(
        url: request.testURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: headerFields
    ) else {
        fatalError("Failed to construct HTTPURLResponse for test")
    }
    return response
}

func httpBodyData(from request: URLRequest) -> Data? {
    if let data = request.httpBody {
        return data
    }

    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        if read <= 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}
