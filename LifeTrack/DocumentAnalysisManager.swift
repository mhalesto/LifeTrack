//
//  DocumentAnalysisManager.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import PDFKit
import UIKit
import Vision

struct DocumentAnalysisResult: Equatable {
    let extractedText: String
    let summary: String
    let suggestedTitle: String?
    let suggestedDueDate: Date?
    let keywords: [String]

    var hasUsefulSignal: Bool {
        !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            suggestedTitle != nil ||
            suggestedDueDate != nil ||
            !keywords.isEmpty
    }
}

enum DocumentAnalysisManager {
    static func analyze(url: URL, displayName: String) async -> DocumentAnalysisResult {
        let extractedText = await extractText(from: url)
        let normalizedText = normalizedStorageText(extractedText)
        let keywords = detectedKeywords(in: "\(displayName) \(normalizedText)")
        let suggestedDueDate = detectedDueDate(in: normalizedText)
        let suggestedTitle = suggestedTitle(
            displayName: displayName,
            text: normalizedText,
            keywords: keywords,
            dueDate: suggestedDueDate
        )

        return DocumentAnalysisResult(
            extractedText: normalizedText,
            summary: summary(
                text: normalizedText,
                keywords: keywords,
                suggestedDueDate: suggestedDueDate,
                references: detectedReferences(in: normalizedText)
            ),
            suggestedTitle: suggestedTitle,
            suggestedDueDate: suggestedDueDate,
            keywords: keywords
        )
    }

    private static func extractText(from url: URL) async -> String {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "pdf" {
            let embeddedText = extractPDFText(from: url)
            if !embeddedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return embeddedText
            }

            return await extractScannedPDFText(from: url)
        }

        if ["png", "jpg", "jpeg", "heic", "tiff", "bmp"].contains(fileExtension) {
            return await extractImageText(from: url)
        }

        if ["txt", "csv", "rtf", "md"].contains(fileExtension),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        return ""
    }

    private static func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return ""
        }

        return document.string ?? ""
    }

    private static func extractScannedPDFText(from url: URL) async -> String {
        guard let document = PDFDocument(url: url) else {
            return ""
        }

        var pageTexts: [String] = []
        let pageLimit = min(document.pageCount, 4)

        for index in 0..<pageLimit {
            guard let page = document.page(at: index) else {
                continue
            }

            let thumbnail = page.thumbnail(of: CGSize(width: 1500, height: 1500), for: .mediaBox)
            guard let cgImage = thumbnail.cgImage else {
                continue
            }

            if let text = try? await recognizeText(in: cgImage) {
                pageTexts.append(text)
            }
        }

        return pageTexts.joined(separator: "\n")
    }

    private static func extractImageText(from url: URL) async -> String {
        guard let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else {
            return ""
        }

        return (try? await recognizeText(in: cgImage)) ?? ""
    }

    private static func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let recognizedStrings = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: recognizedStrings.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func normalizedStorageText(_ text: String) -> String {
        let compacted = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard compacted.count > 24_000 else {
            return compacted
        }

        return String(compacted.prefix(24_000))
    }

    private static func detectedKeywords(in text: String) -> [String] {
        let loweredText = text.lowercased()
        let candidates = [
            "insurance",
            "policy",
            "passport",
            "school",
            "tax",
            "bill",
            "invoice",
            "application",
            "appointment",
            "renewal",
            "deadline",
            "payment",
            "medical",
            "license",
            "statement"
        ]

        return candidates.filter { loweredText.localizedCaseInsensitiveContains($0) }
    }

    private static func detectedDueDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let dates = detector
            .matches(in: text, options: [], range: range)
            .compactMap(\.date)
            .map(defaultTaskTimeIfNeeded)
            .sorted()

        let today = Calendar.current.startOfDay(for: Date())
        return dates.first { $0 >= today } ?? dates.first
    }

    private static func suggestedTitle(
        displayName: String,
        text: String,
        keywords: [String],
        dueDate: Date?
    ) -> String? {
        guard !keywords.isEmpty || dueDate != nil else {
            return nil
        }

        let loweredText = "\(displayName) \(text)".lowercased()
        let baseTitle: String

        if loweredText.contains("invoice") || loweredText.contains("bill") || loweredText.contains("payment due") {
            baseTitle = "Pay invoice"
        } else if loweredText.contains("insurance") || loweredText.contains("policy") || loweredText.contains("renewal") {
            baseTitle = "Renew insurance"
        } else if loweredText.contains("appointment") || loweredText.contains("clinic") || loweredText.contains("doctor") {
            baseTitle = "Book follow-up appointment"
        } else if loweredText.contains("passport") || loweredText.contains("license") {
            baseTitle = "Review renewal document"
        } else if loweredText.contains("tax") {
            baseTitle = "Review tax document"
        } else if loweredText.contains("school") || loweredText.contains("application") {
            baseTitle = "Review application deadline"
        } else {
            baseTitle = "Review document reminder"
        }

        guard let dueDate else {
            return baseTitle
        }

        return "\(baseTitle) by \(dueDate.dayMonthString)"
    }

    private static func summary(
        text: String,
        keywords: [String],
        suggestedDueDate: Date?,
        references: [String]
    ) -> String {
        if text.isEmpty {
            return "No searchable text was detected. The file is still stored securely with this task."
        }

        var parts: [String] = []

        if !keywords.isEmpty {
            parts.append("Detected: \(keywords.prefix(5).joined(separator: ", "))")
        }

        if let suggestedDueDate {
            parts.append("Date found: \(suggestedDueDate.dayMonthString)")
        }

        if !references.isEmpty {
            parts.append(references.prefix(2).joined(separator: " · "))
        }

        if parts.isEmpty {
            return "Searchable text saved locally for this document."
        }

        return parts.joined(separator: ". ")
    }

    private static func detectedReferences(in text: String) -> [String] {
        let patterns = [
            ("Invoice", #"(?i)\b(?:invoice|inv)\s*(?:no\.?|number|#|:)?\s*([A-Z0-9][A-Z0-9\-\/]{3,})"#),
            ("Policy", #"(?i)\bpolicy\s*(?:no\.?|number|#|:)?\s*([A-Z0-9][A-Z0-9\-\/]{3,})"#),
            ("Reference", #"(?i)\b(?:reference|ref)\s*(?:no\.?|number|#|:)?\s*([A-Z0-9][A-Z0-9\-\/]{3,})"#)
        ]

        var references: [String] = []

        for (title, pattern) in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
                match.numberOfRanges > 1,
                let range = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            references.append("\(title): \(String(text[range]))")
        }

        return references
    }

    nonisolated private static func defaultTaskTimeIfNeeded(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)

        guard (components.hour ?? 0) == 0,
              (components.minute ?? 0) == 0,
              (components.second ?? 0) == 0 else {
            return date
        }

        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}
