//
//  ReceiptScanner.swift
//  LifeTrack
//
//  Vision-backed OCR for receipt photos. Returns the recognized text
//  joined newline-separated so ReceiptParser can extract a draft.
//

import Foundation
import UIKit
import Vision

enum ReceiptScanner {
    enum ScanError: Error, LocalizedError {
        case invalidImage
        case noText
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "That image couldn't be read."
            case .noText: return "No text found on the receipt."
            case .underlying(let error): return error.localizedDescription
            }
        }
    }

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.underlying(error))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let joined = lines.joined(separator: "\n")
                if joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: ScanError.noText)
                } else {
                    continuation.resume(returning: joined)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .init(image.imageOrientation))
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.underlying(error))
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
