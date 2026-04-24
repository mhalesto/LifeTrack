//
//  BankStatementReader.swift
//  LifeTrack
//
//  Reads text out of a bank statement file (PDF or plain text/CSV) so
//  it can be handed to `BankStatementImporter`. Isolated from the
//  parsing layer so the pure parser stays testable without PDFKit.
//

import Foundation
import PDFKit

enum BankStatementReader {
    enum ReadError: Error, LocalizedError {
        case cannotAccessFile
        case unreadablePDF
        case emptyDocument
        case unsupportedFileType

        var errorDescription: String? {
            switch self {
            case .cannotAccessFile: "Couldn't open the selected file."
            case .unreadablePDF: "That PDF doesn't have extractable text. Try exporting a text-based statement from your bank."
            case .emptyDocument: "The file is empty."
            case .unsupportedFileType: "Only PDF, CSV, or text statements are supported."
            }
        }
    }

    static func readText(from url: URL) throws -> String {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return try readPDF(url: url)
        case "csv", "txt", "tsv", "ofx", "qfx":
            return try readPlainText(url: url)
        default:
            throw ReadError.unsupportedFileType
        }
    }

    private static func readPDF(url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ReadError.cannotAccessFile
        }
        var collected: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let text = page.string, !text.isEmpty {
                collected.append(text)
            }
        }
        let joined = collected.joined(separator: "\n")
        guard !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReadError.unreadablePDF
        }
        return joined
    }

    private static func readPlainText(url: URL) throws -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
            return text
        }
        if let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .isoLatin1),
           !text.isEmpty {
            return text
        }
        throw ReadError.emptyDocument
    }
}
