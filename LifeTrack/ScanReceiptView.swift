//
//  ScanReceiptView.swift
//  LifeTrack
//
//  Lets the user pick a receipt image, runs Vision OCR + ReceiptParser,
//  then opens LogMoneyView prefilled with the draft.
//

import PhotosUI
import SwiftUI

struct ScanReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var appMoneyCurrencyCode = MoneyCurrency.defaultCode

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var draft: ReceiptDraft?
    @State private var presentedDraft: ReceiptDraft?
    @State private var stage: Stage = .pick
    @State private var errorMessage: String?

    private enum Stage {
        case pick, processing, ready, failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header
                        pickerCard
                        if stage == .processing {
                            processingCard
                        }
                        if let draft, stage == .ready {
                            previewCard(draft: draft)
                        }
                        if stage == .failed, let errorMessage {
                            errorCard(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .navigationDestination(item: $presentedDraft) { draft in
                LogMoneyView(prefilledDraft: draft)
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadImage(from: item) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scan Receipt")
                .font(.lifeTrack(.title, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text("Pick a receipt photo. We'll read the total, date, and merchant on-device.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
    }

    private var pickerCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Receipt Image")

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 1)
                    )
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: image == nil ? "photo.on.rectangle.angled" : "arrow.triangle.2.circlepath")
                    Text(image == nil ? "Choose Receipt Photo" : "Replace Photo")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
        }
    }

    private var processingCard: some View {
        SectionCardView {
            HStack(spacing: 12) {
                ProgressView()
                Text("Reading receipt…")
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
    }

    private func previewCard(draft: ReceiptDraft) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Detected")

            VStack(alignment: .leading, spacing: 8) {
                detectedRow(label: "Merchant", value: draft.merchant)
                detectedRow(label: "Amount", value: MoneyFormatting.currency(draft.amount, code: draft.currencyCode))
                detectedRow(label: "Date", value: DateFormatter.localizedString(from: draft.date, dateStyle: .medium, timeStyle: .none))
                if let category = draft.suggestedCategory {
                    detectedRow(label: "Category", value: category)
                }
            }

            Button {
                self.presentedDraft = draft
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.and.list.clipboard")
                    Text("Review & Save")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
        }
    }

    private func detectedRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func errorCard(message: String) -> some View {
        SectionCardView {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) async {
        stage = .processing
        errorMessage = nil
        draft = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw ReceiptScanner.ScanError.invalidImage
            }
            await MainActor.run { self.image = uiImage }

            let text = try await ReceiptScanner.recognizeText(in: uiImage)
            let parsed = ReceiptParser.parse(
                text,
                defaultCurrencyCode: MoneyCurrency.normalized(appMoneyCurrencyCode)
            )
            await MainActor.run {
                self.draft = parsed
                self.stage = .ready
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.stage = .failed
            }
        }
    }
}

extension ReceiptDraft: Hashable, Identifiable {
    var id: String { rawText.isEmpty ? UUID().uuidString : rawText }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawText)
        hasher.combine(amount)
        hasher.combine(merchant)
        hasher.combine(date)
    }
}
