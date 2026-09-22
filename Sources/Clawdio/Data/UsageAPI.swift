import Foundation

enum UsageError: LocalizedError {
    case noCredentials
    case unreadableCredentials
    case keychainDenied(OSStatus)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case network(String)
    case badResponse

    /// Message dans la langue choisie.
    func message(_ t: Strings) -> String {
        switch self {
        case .noCredentials: t(.errNoCredentials)
        case .unreadableCredentials: t(.errUnreadable)
        case .keychainDenied: t(.errKeychain)
        case .unauthorized: t(.errUnauthorized)
        case .rateLimited: t(.errRateLimited)
        case .http(let code): t(.errHTTP, code)
        case .network(let detail): t(.errNetwork, detail)
        case .badResponse: t(.errNetwork, t(.errBadResponse))
        }
    }

    /// Anglais par défaut (journaux / `LocalizedError`) ; l'UI utilise `message(_:)`.
    var errorDescription: String? { message(Strings(.en)) }

    /// Délai avant la prochaine tentative après cette erreur.
    var retryDelay: Duration {
        switch self {
        case .rateLimited(let after): .seconds(max(after ?? 0, 300)) // le recul exponentiel est géré par UsageModel
        case .unauthorized, .network: .seconds(30)
        default: .seconds(120)
        }
    }
}

struct UsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?   // 0…100
        let resetsAt: Date?
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?
}

enum UsageAPI {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch(token: String) async throws -> UsageResponse {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Clawdio/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw UsageError.http(-1) }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw UsageError.unauthorized
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retry)
        default: throw UsageError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            // "2026-09-21T18:00:00.464516+00:00" — avec ou sans fractions
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) { return date }
            if let date = ISO8601DateFormatter().date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: raw))
        }
        do {
            return try decoder.decode(UsageResponse.self, from: data)
        } catch {
            throw UsageError.badResponse
        }
    }
}
