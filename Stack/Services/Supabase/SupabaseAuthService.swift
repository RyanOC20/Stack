import Foundation

final class SupabaseAuthService {
    private let client: SupabaseClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(client: SupabaseClient,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.client = client
        self.encoder = encoder
        self.decoder = decoder
    }

    func signUp(email: String, password: String) async throws -> SupabaseSession {
        let body = try encoder.encode(AuthPayload(email: email, password: password))
        let request = try client.makeRequest(
            path: "/auth/v1/signup",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        let response: SupabaseAuthResponse = try await client.perform(request, decoder: decoder)
        let session = try response.toSession()
        client.setSession(session)
        return session
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        let body = try encoder.encode(AuthPayload(email: email, password: password))
        let request = try client.makeRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: body,
            requiresAuth: false
        )
        let response: SupabaseAuthResponse = try await client.perform(request, decoder: decoder)
        let session = try response.toSession()
        client.setSession(session)
        return session
    }
}

private struct AuthPayload: Encodable {
    let email: String
    let password: String
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    func toSession() throws -> SupabaseSession {
        guard let accessToken, let refreshToken, let user else {
            throw SupabaseClient.ClientError.missingSession
        }
        return SupabaseSession(accessToken: accessToken, refreshToken: refreshToken, user: user)
    }
}
