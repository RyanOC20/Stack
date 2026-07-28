import Foundation

struct EnvironmentConfiguration: Decodable {
    let supabaseURL: URL
    let supabaseAnonKey: String

    private enum CodingKeys: String, CodingKey {
        case supabaseURL = "SupabaseURL"
        case supabaseAnonKey = "SupabaseAnonKey"
        case supabaseURLUnderscore = "Supabase_URL"
        case supabaseAnonKeyUnderscore = "Supabase_Anon_Key"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let urlString = try container.decodeIfPresent(String.self, forKey: .supabaseURL)
            ?? container.decodeIfPresent(String.self, forKey: .supabaseURLUnderscore)
        let anon = try container.decodeIfPresent(String.self, forKey: .supabaseAnonKey)
            ?? container.decodeIfPresent(String.self, forKey: .supabaseAnonKeyUnderscore)

        guard let urlString, let supabaseAnonKey = anon else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing SupabaseURL/SupabaseAnonKey"))
        }
        guard let supabaseURL = URL(string: urlString) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid SupabaseURL"))
        }

        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    init(supabaseURL: URL, supabaseAnonKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    static func load(logger: Logger? = nil, from bundle: Bundle = .main) -> EnvironmentConfiguration? {
        let env = ProcessInfo.processInfo.environment
        if let urlString = env["SUPABASE_URL"],
           let anonKey = env["SUPABASE_ANON_KEY"],
           let url = URL(string: urlString) {
            logger?.info("Loaded Supabase config from environment variables.")
            return EnvironmentConfiguration(supabaseURL: url, supabaseAnonKey: anonKey)
        }

        guard let url = bundle.url(forResource: "Environment", withExtension: "plist") else {
            logger?.info("Environment.plist not found in bundle.")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            logger?.info("Loaded Environment.plist at \(url.path) (\(data.count) bytes).")
            return try PropertyListDecoder().decode(EnvironmentConfiguration.self, from: data)
        } catch {
            logger?.error("Failed to decode Environment.plist at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
}
