import Foundation

enum AppConfiguration {
    enum Environment: String {
        case debug
        case staging
        case production
    }

    static var current: Environment {
        guard let value = Bundle.main.infoDictionary?["APP_ENVIRONMENT"] as? String,
              let env = Environment(rawValue: value) else {
            return .debug
        }
        return env
    }

    static var baseURL: URL {
        guard let url = URL(string: "https://api.themoviedb.org/3") else {
            fatalError("API_BASE_URL not configured in Info.plist")
        }
        return url
    }

    static var apiToken: String {
        // NOTE: Test-only hardcoded token. Do not use this approach in production.
        "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI0NjEzNDQyNTAwMTA2ZGViZDM1YTJhMmRjODI0MTk1NiIsIm5iZiI6MTQ5MDk4ODg3Ny40NTIsInN1YiI6IjU4ZGVhZjRhOTI1MTQxMWJhNjAwZmRhMiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.ltqpDbDfSjFe86qInxNcThrNXvRlBqBuaaMHFLMDmI8"
    }
}
