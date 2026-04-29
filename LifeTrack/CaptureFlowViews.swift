//
//  CaptureFlowViews.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var rawText = ""
    @State private var captureDraft = CapturedTaskDraft(source: .typed, rawText: "")
    @State private var parseTask: Task<Void, Never>?
    @FocusState private var isEditorFocused: Bool

    let onOpenEditor: (CapturedTaskDraft) -> Void
    let onOpenVoiceCapture: () -> Void
    let onOpenQuickAdd: (() -> Void)?

    private var canPersist: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inbox Capture")
                                .font(.lifeTrackTitle)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            Text("Drop the next thought here. Organize it later when you have time.")
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SectionCardView {
                            SectionHeaderView(
                                title: "Capture",
                                infoMessage: "Save a rough note to inbox first, or jump into the full task editor if you're ready to structure it now."
                            )

                            ZStack(alignment: .topLeading) {
                                if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Type the next thing you need to remember…")
                                        .font(.body)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 15)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: $rawText)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .focused($isEditorFocused)
                            }
                            .background(
                                LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94),
                                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
                            }
                        }

                        if canPersist {
                            CaptureSuggestionsCard(
                                draft: captureDraft,
                                title: "Ready for Inbox",
                                subtitle: "LifeTrack already pulled out the likely task details."
                            )
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    LifeTrackPrimaryButton(
                        title: "Save to Inbox",
                        systemImage: "tray.and.arrow.down",
                        isDisabled: !canPersist,
                        action: saveToInbox
                    )

                    HStack(spacing: 10) {
                        LifeTrackSecondaryButton(title: "Voice Capture", systemImage: "mic.fill") {
                            dismissAndRun(onOpenVoiceCapture)
                        }

                        LifeTrackSecondaryButton(title: "Open Full Task", systemImage: "square.and.pencil") {
                            guard canPersist else { return }
                            let draft = currentDraft()
                            dismissAndRun { onOpenEditor(draft) }
                        }
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditorFocused = false
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let onOpenQuickAdd {
                        Button {
                            dismissAndRun(onOpenQuickAdd)
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                        .accessibilityLabel("Open Quick Add")
                    }
                }
            }
            .onChange(of: rawText) { _, newValue in
                parseTask?.cancel()
                parseTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    captureDraft = CapturedTaskDraft(source: .typed, rawText: newValue)
                }
            }
            .onDisappear {
                parseTask?.cancel()
            }
        }
    }

    private func currentDraft() -> CapturedTaskDraft {
        if captureDraft.rawText == rawText {
            return captureDraft
        }
        return CapturedTaskDraft(source: .typed, rawText: rawText)
    }

    private func saveToInbox() {
        guard canPersist else { return }
        InboxStore.add(currentDraft().makeInboxItem())
        isEditorFocused = false
        dismiss()
    }

    private func dismissAndRun(_ action: @escaping () -> Void) {
        isEditorFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: action)
        }
    }
}

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage(LifeTrackSettings.Keys.voiceTranscriptDisclosureShown) private var voiceTranscriptDisclosureShown = false

    @StateObject private var voiceInput = VoiceTaskInputManager()
    @StateObject private var voiceEnhancer = AIVoiceTaskEnhancer()

    @State private var transcript = ""
    @State private var captureDraft = CapturedTaskDraft(source: .voice, rawText: "")
    @State private var isShowingVoiceTranscriptDisclosure = false
    @State private var isAIEnhancing = false
    @State private var lastEnhancedTranscript = ""
    @FocusState private var isTranscriptFocused: Bool

    let onOpenEditor: (CapturedTaskDraft) -> Void

    private var canPersist: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Voice Capture")
                                .font(.lifeTrackTitle)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            Text("Speak naturally. Save the draft to inbox or create the task directly once it looks right.")
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SectionCardView {
                            SectionHeaderView(
                                title: "Recorder",
                                infoMessage: "Voice capture can stay lightweight here. You only need the full task editor if you want to fine-tune the details."
                            )

                            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                                Button(action: voiceInput.toggleRecording) {
                                    VoiceCaptureRecordButton(isRecording: voiceInput.isRecording, audioLevel: voiceInput.audioLevel)
                                }
                                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.96))

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(voiceInput.isRecording ? "Listening…" : "Transcript ready")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                                        if voiceInput.isRecording {
                                            VoiceCaptureLevelStrip(level: voiceInput.audioLevel)
                                                .frame(width: 96, height: 22)
                                        }
                                    }

                                    Text(voiceInput.feedbackMessage)
                                        .font(.footnote)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if isAIEnhancing {
                                        HStack(spacing: 7) {
                                            ProgressView()
                                                .scaleEffect(0.75)
                                                .tint(LifeTrackTheme.ColorPalette.warning)
                                            Text("Enhancing with AI…")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                                        }
                                    }
                                }
                            }

                            if let authorizationMessage = voiceInput.authorizationMessage {
                                Text(authorizationMessage)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                            }

                            if let enhancementError = voiceEnhancer.error, !enhancementError.isEmpty {
                                Text(enhancementError)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                            }

                            ZStack(alignment: .topLeading) {
                                if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Say: Book a dentist appointment tomorrow after lunch")
                                        .font(.body)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 15)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: $transcript)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 170)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .focused($isTranscriptFocused)
                            }
                            .background(
                                LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94),
                                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
                            }

                            Button(action: clearCapture) {
                                Label("Clear transcript", systemImage: "xmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canPersist)
                            .opacity(canPersist ? 1 : 0.45)
                        }

                        if canPersist {
                            CaptureSuggestionsCard(
                                draft: captureDraft,
                                title: "Detected Task",
                                subtitle: "These fields will be used for inbox save or direct task creation."
                            )
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    LifeTrackPrimaryButton(
                        title: "Create Task",
                        systemImage: "checkmark.circle.fill",
                        isDisabled: !canPersist,
                        action: createTask
                    )

                    HStack(spacing: 10) {
                        LifeTrackSecondaryButton(title: "Save to Inbox", systemImage: "tray.and.arrow.down") {
                            saveToInbox()
                        }

                        LifeTrackSecondaryButton(title: "Open Full Task", systemImage: "square.and.pencil") {
                            guard canPersist else { return }
                            let draft = captureDraft
                            dismissAndRun { onOpenEditor(draft) }
                        }
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isTranscriptFocused = false
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard !voiceInput.isRecording && transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    voiceInput.toggleRecording()
                }
            }
            .onDisappear {
                voiceInput.stopRecording()
            }
            .onChange(of: voiceInput.transcript) { _, newValue in
                transcript = newValue
                refreshDraft(from: newValue)
            }
            .onChange(of: transcript) { _, newValue in
                guard newValue != voiceInput.transcript else { return }
                refreshDraft(from: newValue)
            }
            .onChange(of: voiceInput.isRecording) { wasRecording, isNowRecording in
                guard wasRecording, !isNowRecording else { return }
                guard canPersist else { return }
                guard subscriptionManager.tier >= .ultimate, voiceEnhancer.isConfigured else { return }
                guard transcript != lastEnhancedTranscript else { return }
                Task { await enhanceCurrentDraft() }
            }
            .alert("Send voice note to AI?", isPresented: $isShowingVoiceTranscriptDisclosure) {
                Button("Not now", role: .cancel) { }
                Button("Allow") {
                    voiceTranscriptDisclosureShown = true
                    Task { await enhanceCurrentDraft(forceDisclosureBypass: true) }
                }
            } message: {
                Text("To turn your voice note into a structured task, the transcript is sent to Anthropic's Claude API. Avoid speaking sensitive details you do not want to leave the device.")
            }
        }
    }

    private func refreshDraft(from text: String) {
        lastEnhancedTranscript = ""
        captureDraft = CapturedTaskDraft(source: .voice, rawText: text)
    }

    private func clearCapture() {
        voiceInput.clearTranscript()
        transcript = ""
        captureDraft = CapturedTaskDraft(source: .voice, rawText: "")
        isAIEnhancing = false
        lastEnhancedTranscript = ""
    }

    private func saveToInbox() {
        guard canPersist else { return }
        InboxStore.add(captureDraft.makeInboxItem())
        isTranscriptFocused = false
        dismiss()
    }

    private func createTask() {
        guard canPersist else { return }
        modelContext.insert(captureDraft.makeTask())
        try? modelContext.save()
        isTranscriptFocused = false
        dismiss()
    }

    private func dismissAndRun(_ action: @escaping () -> Void) {
        isTranscriptFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: action)
        }
    }

    private func enhanceCurrentDraft(forceDisclosureBypass: Bool = false) async {
        guard canPersist else { return }

        if !forceDisclosureBypass && !voiceTranscriptDisclosureShown {
            await MainActor.run {
                isShowingVoiceTranscriptDisclosure = true
            }
            return
        }

        await MainActor.run {
            isAIEnhancing = true
        }
        defer {
            Task { @MainActor in
                isAIEnhancing = false
            }
        }

        guard let enhanced = await voiceEnhancer.enhance(transcript: transcript) else {
            return
        }

        await MainActor.run {
            captureDraft.applyEnhancedDraft(enhanced)
            lastEnhancedTranscript = transcript
        }
    }
}

struct InboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var inboxItems: [InboxItem] = InboxStore.loadOpenItems()

    let onOpenEditor: (CapturedTaskDraft) -> Void
    let onOpenTextCapture: () -> Void
    let onOpenVoiceCapture: () -> Void

    private var staleInboxItems: [InboxItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return inboxItems.filter { $0.createdAt < cutoff }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inbox")
                                .font(.lifeTrackTitle)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            Text(inboxItems.isEmpty ? "Nothing waiting right now." : "\(inboxItems.count) captured item\(inboxItems.count == 1 ? "" : "s") ready to triage.")
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }

                        HStack(spacing: 10) {
                            LifeTrackSecondaryButton(title: "Text Capture", systemImage: "square.and.pencil") {
                                dismissAndRun(onOpenTextCapture)
                            }

                            LifeTrackSecondaryButton(title: "Voice Capture", systemImage: "mic.fill") {
                                dismissAndRun(onOpenVoiceCapture)
                            }
                        }

                        if inboxItems.isEmpty {
                            EmptyStateView(
                                title: "Inbox is clear",
                                message: "Capture rough notes here first, then turn them into structured tasks when you're ready.",
                                actionTitle: "Capture Something",
                                action: { dismissAndRun(onOpenTextCapture) }
                            )
                        } else {
                            InboxBatchProcessingCard(
                                itemCount: inboxItems.count,
                                staleCount: staleInboxItems.count,
                                onCreateAll: createAllTasks,
                                onArchiveAll: archiveAll
                            )

                            VStack(spacing: LifeTrackTheme.Spacing.medium) {
                                ForEach(inboxItems) { item in
                                    InboxItemCard(
                                        item: item,
                                        onCreateTask: { createTask(from: item) },
                                        onEditTask: { edit(item) },
                                        onArchive: { archive(item) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshInbox()
            }
        }
    }

    private func createAllTasks() {
        let items = inboxItems
        guard !items.isEmpty else { return }

        let now = Date()
        for item in items {
            modelContext.insert(item.captureDraft.makeTask())
            var updated = item
            updated.markConverted(at: now)
            InboxStore.update(updated)
        }

        try? modelContext.save()
        refreshInbox()
    }

    private func archiveAll() {
        let items = inboxItems
        guard !items.isEmpty else { return }

        let now = Date()
        for item in items {
            var updated = item
            updated.markArchived(at: now)
            InboxStore.update(updated)
        }

        refreshInbox()
    }

    private func createTask(from item: InboxItem) {
        modelContext.insert(item.captureDraft.makeTask())
        var updated = item
        updated.markConverted()
        InboxStore.update(updated)
        try? modelContext.save()
        refreshInbox()
    }

    private func archive(_ item: InboxItem) {
        var updated = item
        updated.markArchived()
        InboxStore.update(updated)
        refreshInbox()
    }

    private func edit(_ item: InboxItem) {
        let draft = item.captureDraft
        dismissAndRun { onOpenEditor(draft) }
    }

    private func dismissAndRun(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: action)
    }

    private func refreshInbox() {
        inboxItems = InboxStore.loadOpenItems()
    }
}

private struct InboxBatchProcessingCard: View {
    let itemCount: Int
    let staleCount: Int
    let onCreateAll: () -> Void
    let onArchiveAll: () -> Void

    var body: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: staleCount > 0 ? "clock.badge.exclamationmark" : "checklist")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(staleCount > 0 ? LifeTrackTheme.ColorPalette.warning : LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        (staleCount > 0 ? LifeTrackTheme.ColorPalette.warning : LifeTrackTheme.ColorPalette.accent).opacity(0.12),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Process inbox")
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                InlineActionPillButton(
                    title: "Create All",
                    systemImage: "checkmark.circle.fill",
                    tint: LifeTrackTheme.ColorPalette.success,
                    action: onCreateAll
                )

                InlineActionPillButton(
                    title: "Archive All",
                    systemImage: "archivebox",
                    tint: LifeTrackTheme.ColorPalette.secondaryText,
                    action: onArchiveAll
                )
            }
        }
    }

    private var summary: String {
        if staleCount > 0 {
            return "\(itemCount) waiting, including \(staleCount) older than a day."
        }

        return "\(itemCount) waiting. Convert the parsed drafts into tasks or archive the noise."
    }
}

private struct InboxItemCard: View {
    let item: InboxItem
    let onCreateTask: () -> Void
    let onEditTask: () -> Void
    let onArchive: () -> Void

    private var draft: CapturedTaskDraft {
        item.captureDraft
    }

    private var detailText: String {
        let notes = draft.resolvedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            return notes
        }

        let raw = item.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.caseInsensitiveCompare(item.previewTitle) != .orderedSame {
            return raw
        }

        return "Saved from \(item.source.title.lowercased()) capture."
    }

    var body: some View {
        SectionCardView {
            HStack(alignment: .center, spacing: 10) {
                CaptureMetadataPill(
                    title: item.source.title,
                    systemImage: item.source.symbolName,
                    tint: sourceTint
                )

                Spacer(minLength: 0)

                Text(item.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }

            Text(item.previewTitle)
                .font(.lifeTrackHeadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(detailText)
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(3)

            HStack(spacing: 8) {
                CaptureMetadataPill(
                    title: TaskCategory.builtInTitle(for: draft.resolvedCategory),
                    systemImage: draft.resolvedCategory.symbolName,
                    tint: draft.resolvedCategory.style.tint
                )

                CaptureMetadataPill(
                    title: draft.resolvedDueDate.weekdayDateString,
                    systemImage: "calendar.badge.clock",
                    tint: LifeTrackTheme.ColorPalette.accent
                )
            }

            HStack(spacing: 10) {
                InlineActionPillButton(
                    title: "Create Task",
                    systemImage: "checkmark.circle.fill",
                    tint: LifeTrackTheme.ColorPalette.success,
                    action: onCreateTask
                )

                InlineActionPillButton(
                    title: "Edit",
                    systemImage: "square.and.pencil",
                    tint: LifeTrackTheme.ColorPalette.accent,
                    action: onEditTask
                )

                InlineActionPillButton(
                    title: "Archive",
                    systemImage: "archivebox",
                    tint: LifeTrackTheme.ColorPalette.secondaryText,
                    action: onArchive
                )
            }
        }
    }

    private var sourceTint: Color {
        switch item.source {
        case .typed:
            LifeTrackTheme.ColorPalette.accent
        case .voice:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .shared:
            LifeTrackTheme.ColorPalette.success
        }
    }
}

private struct CaptureSuggestionsCard: View {
    let draft: CapturedTaskDraft
    let title: String
    let subtitle: String

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 12) {
                suggestionRow(
                    label: "Title",
                    value: draft.resolvedTitle,
                    symbolName: "text.cursor",
                    tint: LifeTrackTheme.ColorPalette.accent
                )

                suggestionRow(
                    label: "Due",
                    value: "\(draft.resolvedDueDate.weekdayDateString) · \(draft.resolvedDueDate.timeString)",
                    symbolName: "calendar.badge.clock",
                    tint: LifeTrackTheme.ColorPalette.secondaryAccent
                )

                HStack(spacing: 8) {
                    CaptureMetadataPill(
                        title: TaskCategory.builtInTitle(for: draft.resolvedCategory),
                        systemImage: draft.resolvedCategory.symbolName,
                        tint: draft.resolvedCategory.style.tint
                    )

                    CaptureMetadataPill(
                        title: draft.resolvedPriority.title,
                        systemImage: draft.resolvedPriority.symbolName,
                        tint: priorityTint
                    )
                }

                if !draft.resolvedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.lifeTrackCaption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                        Text(draft.resolvedNotes)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var priorityTint: Color {
        switch draft.resolvedPriority {
        case .low:
            LifeTrackTheme.ColorPalette.success
        case .normal:
            LifeTrackTheme.ColorPalette.accent
        case .high:
            LifeTrackTheme.ColorPalette.warning
        }
    }

    @ViewBuilder
    private func suggestionRow(label: String, value: String, symbolName: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: Circle())

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
    }
}

private struct CaptureMetadataPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.11), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.14), lineWidth: 0.7)
        }
    }
}

private struct InlineActionPillButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(tint.opacity(0.1), in: Capsule())
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96))
    }
}

private struct VoiceCaptureRecordButton: View {
    let isRecording: Bool
    let audioLevel: CGFloat

    private var reactiveScale: CGFloat {
        isRecording ? 1 + (audioLevel * 0.16) : 1
    }

    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .stroke(LifeTrackTheme.ColorPalette.danger.opacity(0.15 + audioLevel * 0.2), lineWidth: 8 + audioLevel * 8)
                    .frame(width: 82 + audioLevel * 22, height: 82 + audioLevel * 22)
                    .scaleEffect(reactiveScale)
            }

            Circle()
                .fill(isRecording ? LifeTrackTheme.ColorPalette.danger.opacity(0.16) : LifeTrackTheme.ColorPalette.accentSoft)
                .frame(width: 72, height: 72)
                .shadow(
                    color: (isRecording ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.accent).opacity(0.18),
                    radius: 16,
                    x: 0,
                    y: 10
                )

            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isRecording ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.accent)
        }
        .frame(width: 104, height: 104)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.78), value: audioLevel)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

private struct VoiceCaptureLevelStrip: View {
    let level: CGFloat

    private let barCount = 12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 8

            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LifeTrackTheme.ColorPalette.danger.opacity(0.86),
                                    LifeTrackTheme.ColorPalette.warning.opacity(0.84)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: barHeight(index: index, phase: phase))
                }
            }
        }
    }

    private func barHeight(index: Int, phase: TimeInterval) -> CGFloat {
        let clampedLevel = min(max(level, 0.05), 1)
        let wave = 0.58 + (0.42 * CGFloat(sin(phase + Double(index) * 0.62)))
        let centerBias = 1 - abs(CGFloat(index) - CGFloat(barCount - 1) / 2) / CGFloat(barCount)
        return 5 + (clampedLevel * 18 * wave * (0.72 + centerBias))
    }
}

private extension TaskCategory {
    static func builtInTitle(for category: TaskCategory) -> String {
        category.title
    }
}
