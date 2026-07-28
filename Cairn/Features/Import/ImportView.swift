import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ImportViewModel: ObservableObject {
    enum Phase {
        case capture
        case extracting
        case review
    }

    @Published var phase: Phase = .capture
    @Published var candidates: [ExtractedAssignment] = []
    @Published var urlText: String = ""
    @Published var pastedText: String = ""
    @Published var errorMessage: String?

    private let service: ImportService
    private let onConfirm: @MainActor (ExtractedAssignment) -> Void

    init(service: ImportService, onConfirm: @escaping @MainActor (ExtractedAssignment) -> Void) {
        self.service = service
        self.onConfirm = onConfirm
    }

    var includedCount: Int {
        candidates.filter(\.isIncluded).count
    }

    func extractImage(data: Data, mediaType: String) {
        run { try await self.service.extract(from: .image(data: data, mediaType: mediaType)) }
    }

    func extractURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { try await self.service.extract(from: .pageURL(trimmed)) }
    }

    func extractText() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { try await self.service.extract(from: .text(trimmed)) }
    }

    func confirm() {
        for candidate in candidates where candidate.isIncluded {
            onConfirm(candidate)
        }
        reset()
    }

    func reset() {
        candidates = []
        urlText = ""
        pastedText = ""
        errorMessage = nil
        phase = .capture
    }

    private func run(_ operation: @escaping () async throws -> [ExtractedAssignment]) {
        phase = .extracting
        errorMessage = nil
        Task {
            do {
                let results = try await operation()
                candidates = results
                if results.isEmpty {
                    errorMessage = "No assignments found in that source."
                    phase = .capture
                } else {
                    phase = .review
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Extraction failed."
                phase = .capture
            }
        }
    }
}

struct ImportView: View {
    @ObservedObject var viewModel: ImportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .capture:
                CaptureView(viewModel: viewModel, onCancel: { dismiss() })
            case .extracting:
                ExtractingView()
            case .review:
                ImportReviewView(
                    viewModel: viewModel,
                    onCancel: { viewModel.reset(); dismiss() },
                    onConfirm: { viewModel.confirm(); dismiss() }
                )
            }
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(ColorPalette.background)
        .foregroundColor(ColorPalette.textPrimary)
    }
}

// MARK: - Capture

private struct CaptureView: View {
    @ObservedObject var viewModel: ImportViewModel
    let onCancel: () -> Void

    @State private var showFileImporter = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import assignments")
                .font(Typography.assignmentName)
            Text("Drop a screenshot, paste an image or text, or point at a class page. Cairn reads it and pulls out the assignments for you to review.")
                .font(Typography.secondary)
                .foregroundColor(ColorPalette.textSecondary)

            dropZone

            HStack(spacing: 12) {
                Button("Choose Image…") { showFileImporter = true }
                Button("Paste") { pasteFromClipboard() }
            }

            Divider().overlay(ColorPalette.textSecondary.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                Text("Class page URL")
                    .font(Typography.secondary)
                    .foregroundColor(ColorPalette.textSecondary)
                HStack {
                    TextField("https://…", text: $viewModel.urlText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.extractURL() }
                    Button("Extract") { viewModel.extractURL() }
                        .disabled(viewModel.urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Or paste text")
                    .font(Typography.secondary)
                    .foregroundColor(ColorPalette.textSecondary)
                TextEditor(text: $viewModel.pastedText)
                    .font(Typography.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(ColorPalette.rowSelection)
                    .cornerRadius(6)
                Button("Extract from Text") { viewModel.extractText() }
                    .disabled(viewModel.pastedText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(Typography.secondary)
                    .foregroundColor(ColorPalette.dueSoon)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.png, .jpeg, .image],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                loadImage(from: url)
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isDropTargeted ? ColorPalette.accent : ColorPalette.textSecondary.opacity(0.35),
                style: StrokeStyle(lineWidth: 1.5, dash: [6])
            )
            .frame(height: 120)
            .overlay(
                Text("Drop a screenshot here")
                    .font(Typography.secondary)
                    .foregroundColor(ColorPalette.textSecondary)
            )
            .background(isDropTargeted ? ColorPalette.accentMuted : Color.clear)
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { loadImage(from: url) }
        }
        return true
    }

    private func loadImage(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            viewModel.errorMessage = "Could not read that file."
            return
        }
        viewModel.extractImage(data: data, mediaType: Self.mediaType(for: url))
    }

    private static func mediaType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) {
            viewModel.extractImage(data: data, mediaType: "image/png")
        } else if let tiff = pasteboard.data(forType: .tiff),
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) {
            viewModel.extractImage(data: png, mediaType: "image/png")
        } else if let string = pasteboard.string(forType: .string) {
            viewModel.pastedText = string
            viewModel.extractText()
        } else {
            viewModel.errorMessage = "Clipboard has no image or text."
        }
    }
}

// MARK: - Extracting

private struct ExtractingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Reading your assignments…")
                .font(Typography.secondary)
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review

struct ImportReviewView: View {
    @ObservedObject var viewModel: ImportViewModel
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review \(viewModel.candidates.count) found")
                    .font(Typography.assignmentName)
                Spacer()
            }
            .padding(24)

            List {
                ForEach($viewModel.candidates) { $candidate in
                    ImportReviewRow(candidate: $candidate)
                        .listRowBackground(ColorPalette.background)
                }
            }
            .scrollContentBackground(.hidden)

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add \(viewModel.includedCount)") { onConfirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.includedCount == 0)
            }
            .padding(24)
        }
    }
}

private struct ImportReviewRow: View {
    @Binding var candidate: ExtractedAssignment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $candidate.isIncluded)
                .labelsHidden()
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Name", text: $candidate.name)
                    .textFieldStyle(.plain)
                    .font(Typography.assignmentName)

                HStack(spacing: 8) {
                    TextField("Course", text: $candidate.course)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    Picker("", selection: $candidate.type) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 130)

                    Picker("", selection: $candidate.status) {
                        ForEach(AssignmentStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 130)
                }

                HStack(spacing: 8) {
                    DatePicker("", selection: $candidate.dueAt)
                        .labelsHidden()
                    Text("\(Int((candidate.confidence * 100).rounded()))% sure")
                        .font(Typography.secondary)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .opacity(candidate.isIncluded ? 1 : 0.5)
        .padding(.vertical, 6)
    }
}
