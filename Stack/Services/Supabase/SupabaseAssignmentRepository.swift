import Foundation

final class SupabaseAssignmentRepository: AssignmentRepositoryProtocol {
    private let client: SupabaseClient
    private let logger: Logger
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoWithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let fallbackRFC3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()

    init(client: SupabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let string = SupabaseAssignmentRepository.isoWithFractional.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = SupabaseAssignmentRepository.isoWithFractional.date(from: string)
                ?? SupabaseAssignmentRepository.isoWithoutFractional.date(from: string)
                ?? SupabaseAssignmentRepository.fallbackRFC3339.date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ISO8601 date: \(string)"
                )
            )
        }
        self.decoder = decoder
    }

    func fetchAssignments() async throws -> [Assignment] {
        let request = try client.makeRequest(
            path: "/rest/v1/assignments",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "due_at")
            ]
        )
        let dtos: [AssignmentDTO] = try await client.perform(request, decoder: decoder)
        let assignments = dtos.map { $0.toModel() }
        return assignments.sorted { lhs, rhs in
            if lhs.dueAt == rhs.dueAt {
                return lhs.name < rhs.name
            }
            return lhs.dueAt < rhs.dueAt
        }
    }

    func upsertAssignment(_ assignment: Assignment) async throws {
        guard let userId = client.currentUserID else {
            throw SupabaseClient.ClientError.missingSession
        }

        let dto = AssignmentDTO(assignment: assignment, userId: userId)
        let body = try encoder.encode([dto])
        let request = try client.makeRequest(
            path: "/rest/v1/assignments",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: body,
            preferHeader: "return=representation,resolution=merge-duplicates"
        )
        _ = try await client.perform(request, decoder: decoder) as [AssignmentDTO]
    }

    func deleteAssignment(id: UUID) async throws {
        let request = try client.makeRequest(
            path: "/rest/v1/assignments",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        )
        try await client.performVoid(request)
    }
}
