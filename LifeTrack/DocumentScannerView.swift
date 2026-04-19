//
//  DocumentScannerView.swift
//  LifeTrack
//

import PDFKit
import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    enum ScanError: Error {
        case cancelled
        case emptyScan
        case pdfGenerationFailed
    }

    let onFinish: (Result<URL, Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: (Result<URL, Error>) -> Void

        init(onFinish: @escaping (Result<URL, Error>) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            controller.dismiss(animated: true)

            guard scan.pageCount > 0 else {
                onFinish(.failure(ScanError.emptyScan))
                return
            }

            do {
                let url = try ScannedDocumentWriter.writePDF(from: scan)
                onFinish(.success(url))
            } catch {
                onFinish(.failure(error))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onFinish(.failure(ScanError.cancelled))
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
            onFinish(.failure(error))
        }
    }
}

enum ScannedDocumentWriter {
    static func writePDF(from scan: VNDocumentCameraScan) throws -> URL {
        let pdfDocument = PDFDocument()

        for index in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: index)
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: pdfDocument.pageCount)
        }

        guard pdfDocument.pageCount > 0, let data = pdfDocument.dataRepresentation() else {
            throw DocumentScannerView.ScanError.pdfGenerationFailed
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeTrackScans", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileName = "\(defaultDisplayName()).pdf"
        let destination = tempDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func defaultDisplayName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Scan \(formatter.string(from: date))"
    }
}
