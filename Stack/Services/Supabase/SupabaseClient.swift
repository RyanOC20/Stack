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
    let status: Int?
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
            if let mappedError = try? decoder.decode(SupabaseErrorResponse.self, from: data) {
                throw mappedError
            }
            throw ClientError.invalidResponse
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
