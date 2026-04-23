//
//  ClaudeAPIClient.swift
//  LifeTrack
//
//  Shared Anthropic client with prompt caching, response dedup caching,
//  daily budget enforcement and a dedicated URLSession to avoid -1017 errors.
//

import CryptoKit
import Foundation

// Defined outside ClaudeAPIClient so these string constants are nonisolated
// and can be used as default parameter values without a @MainActor context.
nonisolated enum ClaudeModel {
    static let haiku  = "claude-haiku-4-5-20251001"
    static let sonnet = "claude-sonnet-4-6"
}

@MainActor
final class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()

    typealias Model = ClaudeModel

    enum ClientError: LocalizedError {
        case missingAPIKey
        case budgetExceeded(used: Int, cap: Int)
        case http(Int, String)
        case parse(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Claude API key in Settings to use AI features."
            case let .budgetExceeded(used, cap):
                return "Daily AI call limit reached (\(used)/\(cap)). Try again tomorrow."
            case let .http(code, body):
                return "HTTP \(code): \(body.prefix(300))"
            case let .parse(body):
                return "Couldn't parse Claude's reply. First 200 chars: \(body.prefix(200))"
            }
        }
    }

    // MARK: - Dedicated session

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: - Response cache (in-memory, TTL per request)

    private struct CacheEntry {
        let text: String
        let stored: Date
    }

    private var responseCache: [String: CacheEntry] = [:]

    // MARK: - Public API

    private var apiKey: String {
        UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.claudeAPIKey) ?? ""
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    /// Send a single-turn request.
    /// - Parameters:
    ///   - system: Static system prompt (marked as ephemeral for caching on the server side).
    ///   - userContent: The dynamic user content.
    ///   - model: Model id. Defaults to Haiku.
    ///   - maxTokens: Max output tokens.
    ///   - cacheTTL: If set, dedup identical (system+user+model) requests within this interval (seconds).
    ///              Use `.infinity` for permanent cache (e.g. emoji lookups).
    ///   - cacheSystem: If true, attach `cache_control: ephemeral` to the system block so the
    ///                  Anthropic API caches it (90% discount on repeated prefixes when over the
    ///                  minimum prefix-token threshold).
    func send(
        system: String,
        userContent: String,
        model: String = ClaudeModel.haiku,
        maxTokens: Int = 512,
        cacheTTL: TimeInterval? = nil,
        cacheSystem: Bool = true
    ) async throws -> String {
        let key = Self.cacheKey(model: model, system: system, user: userContent, maxTokens: maxTokens)

        if let ttl = cacheTTL, let hit = responseCache[key] {
            let age = Date().timeIntervalSince(hit.stored)
            if ttl.isInfinite || age < ttl {
                return hit.text
            }
        }

        guard isConfigured else { throw ClientError.missingAPIKey }
        try APIBudgetTracker.shared.consumeOne()

        let text = try await performRequest(
            system: system,
            userContent: userContent,
            model: model,
            maxTokens: maxTokens,
            cacheSystem: cacheSystem
        )

        if cacheTTL != nil {
            responseCache[key] = CacheEntry(text: text, stored: Date())
        }

        return text
    }

    /// Clear all in-memory response cache entries (e.g. when the user resets preferences).
    func clearResponseCache() {
        responseCache.removeAll()
    }

    // MARK: - Private

    private func performRequest(
        system: String,
        userContent: String,
        model: String,
        maxTokens: Int,
        cacheSystem: Bool
    ) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30

        let systemBlock: Any
        if cacheSystem {
            systemBlock = [[
                "type": "text",
                "text": system,
                "cache_control": ["type": "ephemeral"]
            ]]
        } else {
            systemBlock = system
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemBlock,
            "messages": [["role": "user", "content": userContent]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let raw = String(data: data, encoding: .utf8) ?? "empty"

        guard status == 200 else {
            throw ClientError.http(status, raw)
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = (json?["content"] as? [[String: Any]])?.first?["text"] as? String else {
            throw ClientError.parse(raw)
        }
        return text
    }

    private static func cacheKey(model: String, system: String, user: String, maxTokens: Int) -> String {
        let combined = "\(model)|\(maxTokens)|\(system)|\(user)"
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - JSON fence-strip helper reused across call sites

    static func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNL = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNL)...])
            }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceEnd.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}"), first <= last {
            s = String(s[first...last])
        }
        return s
    }
}
