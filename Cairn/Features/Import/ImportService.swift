import Foundation

/// Drives the AI ingestion round-trip: records provenance, uploads the source
/// image (best effort), and calls the `extract-assignments` Edge Function. It
/// never writes assignments — confirmed candidates go through the normal
/// repository path so RLS and undo/redo behave exactly as for manual entry.
final class ImportService {
    enum Source {
        case image(data: Data, mediaType: String)
        case pageURL(String)
        case text(String)
    }

    enum ImportError: LocalizedError {
        case functionFailed(String)

        var errorDescription: String? {
            switch self {
            case .functionFailed(let message):
                return message
            }
        }
    }

    private let client: SupabaseClient
    private let logger: Logger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(client: SupabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    /// Extracts candidate assignments from a source. Records an `imports` row and,
    /// for images, uploads the bytes to Storage for provenance (both best effort).
    func extract(from source: Source,
                 now: Date = Date(),
                 timeZone: TimeZone = .current) async throws -> [ExtractedAssignment] {
        let sourceType: String
        var sourceRef: String?

        switch source {
        case .image:
            sourceType = "screenshot"
        case .pageURL(let url):
            sourceType = "url"
            sourceRef = url
        case .text:
            sourceType = "text"
        }

        let importID = await recordImport(sourceType: sourceType, sourceRef: sourceRef)

        if case let .image(data, mediaType) = source, let importID {
            if let objectPath = await uploadImage(data: data, mediaType: mediaType, importID: importID) {
                await updateImportSourceRef(importID: importID, sourceRef: objectPath)
            }
        }

        let functionRequest = makeFunctionRequest(source: source, now: now, timeZone: timeZone)
        let body = try encoder.encode(functionRequest)
        let request = try client.makeRequest(
            path: "/functions/v1/extract-assignments",
            method: "POST",
            body: body
        )

        do {
            let response: ExtractionResponseDTO = try await client.perform(request, decoder: decoder)
            return response.assignments
                .compactMap { $0.toModel() }
                .sorted { $0.dueAt < $1.dueAt }
        } catch let error as SupabaseErrorResponse {
            let message = error.message ?? error.error ?? "Extraction failed."
            logger.error("extract-assignments failed: \(message)")
            throw ImportError.functionFailed(message)
        }
    }

    // MARK: - Provenance (best effort)

    private struct ImportInsert: Encodable {
        let source_type: String
        let source_ref: String?
    }

    private struct ImportRecordDTO: Decodable {
        let id: UUID
    }

    private func recordImport(sourceType: String, sourceRef: String?) async -> UUID? {
        do {
            let body = try encoder.encode([ImportInsert(source_type: sourceType, source_ref: sourceRef)])
            let request = try client.makeRequest(
                path: "/rest/v1/imports",
                method: "POST",
                body: body,
                preferHeader: "return=representation"
            )
            let records: [ImportRecordDTO] = try await client.perform(request, decoder: decoder)
            return records.first?.id
        } catch {
            logger.error("Failed to record import: \(error.localizedDescription)")
            return nil
        }
    }

    private func updateImportSourceRef(importID: UUID, sourceRef: String) async {
        do {
            let body = try encoder.encode(["source_ref": sourceRef])
            let request = try client.makeRequest(
                path: "/rest/v1/imports",
                method: "PATCH",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(importID.uuidString)")],
                body: body
            )
            try await client.performVoid(request)
        } catch {
            logger.error("Failed to update import source ref: \(error.localizedDescription)")
        }
    }

    /// Uploads image bytes to the `imports` bucket under `{userID}/{importID}.{ext}`.
    /// Returns the object path on success. Best effort.
    private func uploadImage(data: Data, mediaType: String, importID: UUID) async -> String? {
        guard let userID = client.currentUserID else { return nil }
        let objectPath = "\(userID.uuidString)/\(importID.uuidString).\(Self.fileExtension(for: mediaType))"
        do {
            var request = try client.makeRequest(
                path: "/storage/v1/object/imports/\(objectPath)",
                method: "POST",
                body: data
            )
            request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
            try await client.performVoid(request)
            return objectPath
        } catch {
            logger.error("Failed to upload import image: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fileExtension(for mediaType: String) -> String {
        switch mediaType {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        default: return "png"
        }
    }

    // MARK: - Function request

    private struct FunctionRequest: Encodable {
        var imageBase64: String?
        var mediaType: String?
        var pageUrl: String?
        var text: String?
        let now: String
        let timeZone: String
    }

    private func makeFunctionRequest(source: Source, now: Date, timeZone: TimeZone) -> FunctionRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        var request = FunctionRequest(now: formatter.string(from: now), timeZone: timeZone.identifier)

        switch source {
        case let .image(data, mediaType):
            request.imageBase64 = data.base64EncodedString()
            request.mediaType = mediaType
        case let .pageURL(url):
            request.pageUrl = url
        case let .text(text):
            request.text = text
        }
        return request
    }
}
