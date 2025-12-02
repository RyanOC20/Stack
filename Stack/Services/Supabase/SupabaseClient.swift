import Foundation

struct SupabaseUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseErrorResponse: Decodable, Error {
    let message: String?
    let error: String?
    let errorDescription: String?
    let status: Int?
    let rawBody: String?

    init(message: String?, error: String?, errorDescription: String? = nil, status: Int?, rawBody: String? = nil) {
        self.message = message
        self.error = error
        self.errorDescription = errorDescription
        self.status = status
        self.rawBody = rawBody
    }

    private enum CodingKeys: String, CodingKey {
        case message
        case error
        case errorDescription = "error_description"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let message = try container.decodeIfPresent(String.self, forKey: .message)
        let error = try container.decodeIfPresent(String.self, forKey: .error)
        let errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        let status = try container.decodeIfPresent(Int.self, forKey: .status)
        self.init(message: message, error: error, errorDescription: errorDescription, status: status)
    }
}

final class SupabaseClient {
    struct Configuration {
        let url: URL
        let anonKey: String
    }

    enum ClientError: Error {
        case missingSession
        case invalidResponse
    }

    let configuration: Configuration
    private let urlSession: URLSession
    private var session: SupabaseSession?

    init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    var currentUserID: UUID? {
        session?.user.id
    }

    func setSession(_ session: SupabaseSession) {
        self.session = session
    }

    func clearSession() {
        session = nil
    }

    func makeRequest(path: String,
                     method: String = "GET",
                     queryItems: [URLQueryItem] = [],
                     body: Data? = nil,
                     preferHeader: String? = nil,
                     requiresAuth: Bool = true) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.url, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidResponse
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw ClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        if let preferHeader {
            request.setValue(preferHeader, forHTTPHeaderField: "Prefer")
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth {
            guard let accessToken = session?.accessToken else {
                throw ClientError.missingSession
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    func perform<T: Decodable>(_ request: URLRequest, decoder: JSONDecoder) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            if let mappedError = try? decoder.decode(SupabaseErrorResponse.self, from: data) {
                throw SupabaseErrorResponse(
                    message: mappedError.message,
                    error: mappedError.error,
                    errorDescription: mappedError.errorDescription,
                    status: mappedError.status ?? httpResponse.statusCode,
                    rawBody: bodyString
                )
            }
            throw SupabaseErrorResponse(
                message: nil,
                error: bodyString,
                errorDescription: nil,
                status: httpResponse.statusCode,
                rawBody: bodyString
            )
        }

        return try decoder.decode(T.self, from: data)
    }

    func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let mappedError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                throw mappedError
            }
            throw ClientError.invalidResponse
        }
    }
}
