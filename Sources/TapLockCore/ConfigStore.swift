import Foundation

/// Persists and loads relaxing session configuration as JSON.
public struct ConfigStore {

    private static var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("taplock")
    }

    private static var configFilePath: URL {
        configDirectory.appendingPathComponent("relax-config.json")
    }

    public static func loadRelaxConfig() -> RelaxingSessionConfig? {
        guard let data = try? Data(contentsOf: configFilePath) else { return nil }
        do {
            return try JSONDecoder().decode(RelaxingSessionConfig.self, from: data)
        } catch {
            fputs("Warning: Could not read config file: \(error.localizedDescription)\n", stderr)
            return nil
        }
    }

    public static func saveRelaxConfig(_ config: RelaxingSessionConfig) throws {
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: configFilePath, options: .atomic)
    }

    public static func removeRelaxConfig() throws {
        let path = configFilePath
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
}
