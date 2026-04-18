//
//  VoiceTaskInputManager.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import AVFoundation
import Combine
import Foundation
import CoreGraphics
import Speech

@MainActor
final class VoiceTaskInputManager: NSObject, ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: CGFloat = 0
    @Published private(set) var feedbackMessage = "Tap the microphone and describe the task."
    @Published private(set) var authorizationMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording()
            }
        }
    }

    func clearTranscript() {
        transcript = ""
        audioLevel = 0
        feedbackMessage = "Tap the microphone and describe the task."
    }

    private func startRecording() async {
        guard await requestPermissions() else {
            return
        }

        do {
            try startRecognitionSession()
        } catch {
            authorizationMessage = "Voice input could not start. Please try again."
            feedbackMessage = "Voice input unavailable."
            stopRecording()
        }
    }

    private func requestPermissions() async -> Bool {
        guard speechRecognizer != nil else {
            authorizationMessage = "Speech recognition is not available for this locale."
            feedbackMessage = "Voice input unavailable."
            return false
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            authorizationMessage = "Enable Speech Recognition in Settings to create tasks by voice."
            feedbackMessage = "Speech recognition needs permission."
            return false
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard microphoneAllowed else {
            authorizationMessage = "Enable Microphone access in Settings to create tasks by voice."
            feedbackMessage = "Microphone needs permission."
            return false
        }

        authorizationMessage = nil
        return true
    }

    private func startRecognitionSession() throws {
        cancelRecognitionSession()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self, weak request] buffer, _ in
            request?.append(buffer)

            let nextAudioLevel = Self.normalizedAudioLevel(from: buffer)
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else {
                    return
                }

                self.audioLevel = (self.audioLevel * 0.62) + (nextAudioLevel * 0.38)
            }
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.feedbackMessage = result.isFinal ? "Voice draft captured." : "Listening..."

                    if result.isFinal {
                        self.finishRecording()
                    }
                }

                if error != nil {
                    self.feedbackMessage = self.transcript.isEmpty ? "No speech captured." : "Voice draft captured."
                    self.finishRecording()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        audioLevel = 0.08
        feedbackMessage = "Listening..."
    }

    func stopRecording() {
        guard isRecording || audioEngine.isRunning else {
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
        audioLevel = 0
        feedbackMessage = transcript.isEmpty ? "No speech captured." : "Voice draft ready to apply."
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cancelRecognitionSession() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        audioLevel = 0
    }

    private nonisolated static func normalizedAudioLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let channelCount = max(Int(buffer.format.channelCount), 1)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        var totalPower: Float = 0
        for channelIndex in 0..<channelCount {
            let samples = channelData[channelIndex]
            for frameIndex in 0..<frameLength {
                let sample = samples[frameIndex]
                totalPower += sample * sample
            }
        }

        let meanPower = totalPower / Float(frameLength * channelCount)
        let rootMeanSquare = sqrt(max(meanPower, 0.000_000_1))
        let decibels = 20 * log10(rootMeanSquare)
        let normalized = (decibels + 56) / 48

        return CGFloat(min(max(normalized, 0), 1))
    }
}
