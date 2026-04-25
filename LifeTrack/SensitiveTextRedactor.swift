//
//  SensitiveTextRedactor.swift
//  LifeTrack
//
//  Best-effort regex stripping of patterns that look like personal
//  identifiers (phones, emails, ID numbers, long digit runs) before
//  text is sent to a third-party AI service.
//
//  This is *not* a guarantee of anonymity — it's a defence-in-depth
//  layer on top of the user's own discretion.
//

import Foundation

enum SensitiveTextRedactor {
    private static let patterns: [(NSRegularExpression, String)] = {
        let raw: [(String, String)] = [
            // Email addresses
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "[email]"),
            // International phone numbers (loose)
            (#"\+?\d[\d\s\-().]{7,}\d"#, "[phone]"),
            // ZA ID numbers (13-digit run)
            (#"\b\d{13}\b"#, "[id]"),
            // Long digit runs (card / account / passport)
            (#"\b\d{9,}\b"#, "[number]"),
            // Postal codes attached to "address" / "addr"
            (#"\b\d{4,6}\b(?=\s*(?:street|st\.|avenue|ave\.|road|rd\.))"#, "[postcode]")
        ]
        return raw.compactMap { pattern, replacement in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            return (regex, replacement)
        }
    }()

    static func redact(_ input: String) -> String {
        var output = input
        for (regex, replacement) in patterns {
            let range = NSRange(output.startIndex..., in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }
        return output
    }
}
