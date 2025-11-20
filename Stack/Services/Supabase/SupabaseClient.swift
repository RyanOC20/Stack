import Foundation

final class SupabaseClient {
    struct Configuration {
        let url: URL
        let anonKey: String
    }

    let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }
}
