import Foundation

/// Client for the shared online high-score board (the Cloudflare Worker in
/// `leaderboard/`; see leaderboard/README.md). When `baseURL` is empty the board
/// is disabled and the game falls back to the personal best — nothing breaks
/// before the backend is deployed. Swift 5 completion-handler style (no strict
/// concurrency); callbacks are delivered on the main queue.
enum Leaderboard {

    /// Set this to your deployed Worker URL after `wrangler deploy`
    /// (e.g. "https://crystal-caper-leaderboard.you.workers.dev"). Empty = disabled.
    static let baseURL = ""

    static var isEnabled: Bool { !baseURL.isEmpty }

    struct Entry: Decodable { let name: String; let score: Int; let level: Int }
    private struct TopResponse: Decodable { let top: [Entry] }
    private struct SubmitResponse: Decodable { let top: [Entry]? }
    private struct Submission: Encodable { let name: String; let score: Int; let level: Int }

    /// Persisted initials (≤6 chars), captured once. Shares the `cc_initials` key
    /// concept with the web build.
    static var initials: String {
        get { UserDefaults.standard.string(forKey: "cc_initials") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "cc_initials") }
    }

    /// Fetch the top entries. Completion is delivered on the main queue.
    static func fetchTop(completion: @escaping ([Entry]) -> Void) {
        guard isEnabled, let url = URL(string: baseURL + "/top") else { completion([]); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let entries = data.flatMap { try? JSONDecoder().decode(TopResponse.self, from: $0).top } ?? []
            DispatchQueue.main.async { completion(entries) }
        }.resume()
    }

    /// Submit a score; completion returns the refreshed top list (main queue).
    static func submit(name: String, score: Int, level: Int, completion: @escaping ([Entry]) -> Void) {
        guard isEnabled, let url = URL(string: baseURL + "/submit") else { completion([]); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(Submission(name: name, score: score, level: level))
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let top = data.flatMap { try? JSONDecoder().decode(SubmitResponse.self, from: $0).top } ?? []
            DispatchQueue.main.async { completion(top) }
        }.resume()
    }

    /// Sanitize free-text initials to the same shape the Worker enforces.
    static func sanitize(_ raw: String) -> String {
        let cleaned = raw.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let s = String(String.UnicodeScalarView(cleaned)).prefix(6)
        return s.isEmpty ? "???" : String(s)
    }
}
