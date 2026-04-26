//
//  VoiceInputCard.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct VoiceInputCard: View {
    @Binding var transcript: String
    let isRecording: Bool
    let audioLevel: CGFloat
    let feedbackMessage: String
    let authorizationMessage: String?
    let isEnhancing: Bool
    let onToggleRecording: () -> Void
    let onApplyTranscript: () -> Void
    let onClearTranscript: () -> Void

    init(
        transcript: Binding<String>,
        isRecording: Bool,
        audioLevel: CGFloat,
        feedbackMessage: String,
        authorizationMessage: String?,
        isEnhancing: Bool = false,
        onToggleRecording: @escaping () -> Void,
        onApplyTranscript: @escaping () -> Void,
        onClearTranscript: @escaping () -> Void
    ) {
        self._transcript = transcript
        self.isRecording = isRecording
        self.audioLevel = audioLevel
        self.feedbackMessage = feedbackMessage
        self.authorizationMessage = authorizationMessage
        self.isEnhancing = isEnhancing
        self.onToggleRecording = onToggleRecording
        self.onApplyTranscript = onApplyTranscript
        self.onClearTranscript = onClearTranscript
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Voice Capture",
                infoMessage: "Speak naturally. LifeTrack will draft the task details."
            )

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Button(action: onToggleRecording) {
                    RecordingButtonIcon(isRecording: isRecording, audioLevel: audioLevel)
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.96))
                .accessibilityLabel(isRecording ? "Stop recording" : "Start voice input")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(isRecording ? "Recording" : "Voice input")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                        if isRecording {
                            VoiceLevelMeterView(level: audioLevel, isRecording: isRecording)
                                .frame(width: 84, height: 24)
                        }
                    }

                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Transcript")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                ZStack(alignment: .topLeading) {
                    if transcript.isEmpty {
                        Text("Say: Book a dentist appointment tomorrow")
                            .font(.body)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                            .padding(13)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $transcript, axis: .vertical)
                        .font(.body.weight(.medium))
                        .foregroundColor(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2...5)
                        .padding(13)
                        .textFieldStyle(.plain)
                        .tint(LifeTrackTheme.ColorPalette.accent)
                }
                .frame(minHeight: 74, alignment: .topLeading)
                .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                }
            }

            if isEnhancing {
                HStack(spacing: 7) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color(red: 0.95, green: 0.72, blue: 0.1))
                    Text("Enhancing with AI…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.1))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.95, green: 0.72, blue: 0.1).opacity(0.1), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
            }

            if let authorizationMessage {
                Text(authorizationMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Button(action: onApplyTranscript) {
                    Label("Apply Draft", systemImage: "sparkles")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LifeTrackTheme.ColorPalette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                Button(action: onClearTranscript) {
                    Label("Clear", systemImage: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(transcript.isEmpty)
                .opacity(transcript.isEmpty ? 0.45 : 1)

                Spacer()
            }
        }
    }
}

private struct RecordingButtonIcon: View {
    let isRecording: Bool
    let audioLevel: CGFloat

    private var reactiveScale: CGFloat {
        isRecording ? 1 + (audioLevel * 0.16) : 1
    }

    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .stroke(LifeTrackTheme.ColorPalette.danger.opacity(0.12 + audioLevel * 0.18), lineWidth: 8 + audioLevel * 7)
                    .frame(width: 70 + audioLevel * 16, height: 70 + audioLevel * 16)
                    .scaleEffect(reactiveScale)

                Circle()
                    .stroke(LifeTrackTheme.ColorPalette.danger.opacity(0.08 + audioLevel * 0.12), lineWidth: 1.2)
                    .frame(width: 84 + audioLevel * 18, height: 84 + audioLevel * 18)
                    .scaleEffect(1 + audioLevel * 0.10)
            }

            Circle()
                .fill(isRecording ? LifeTrackTheme.ColorPalette.danger.opacity(0.14) : LifeTrackTheme.ColorPalette.accentSoft)
                .frame(width: 54, height: 54)
                .shadow(color: isRecording ? LifeTrackTheme.ColorPalette.danger.opacity(0.16) : LifeTrackTheme.ColorPalette.accent.opacity(0.08), radius: 12, x: 0, y: 7)

            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isRecording ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.accent)
        }
        .frame(width: 88, height: 88)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.78), value: audioLevel)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .accessibilityHidden(true)
    }
}

private struct VoiceLevelMeterView: View {
    let level: CGFloat
    let isRecording: Bool

    private let barCount = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 28.0, paused: !isRecording)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 7.5

            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LifeTrackTheme.ColorPalette.danger.opacity(0.82),
                                    LifeTrackTheme.ColorPalette.warning.opacity(0.82)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: barHeight(for: index, phase: phase))
                        .opacity(isRecording ? 0.98 : 0.35)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityLabel("Voice level")
    }

    private func barHeight(for index: Int, phase: TimeInterval) -> CGFloat {
        let clampedLevel = min(max(level, 0.04), 1)
        let wave = 0.55 + (0.45 * CGFloat(sin(phase + Double(index) * 0.68)))
        let centerBias = 1 - abs(CGFloat(index) - CGFloat(barCount - 1) / 2) / CGFloat(barCount)
        let lift = 0.55 + centerBias
        return 5 + (clampedLevel * 21 * wave * lift)
    }
}

#Preview {
    VoiceInputCard(
        transcript: .constant("Book a doctor appointment tomorrow"),
        isRecording: true,
        audioLevel: 0.62,
        feedbackMessage: "Listening...",
        authorizationMessage: nil,
        onToggleRecording: {},
        onApplyTranscript: {},
        onClearTranscript: {}
    )
    .padding()
    .background(LifeTrackTheme.appBackground)
}
