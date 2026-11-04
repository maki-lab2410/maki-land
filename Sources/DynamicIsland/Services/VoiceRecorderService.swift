import Foundation
import AVFoundation
import AppKit
import SwiftUI

public class VoiceRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = VoiceRecorderService()

    @Published public var isRecording: Bool = false
    @Published public var durationSeconds: Int = 0
    @Published public var audioLevels: [CGFloat] = [0.2, 0.35, 0.5, 0.25, 0.45, 0.65, 0.3, 0.5]
    @Published public var isSaving: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var lastSavedBanner: String? = nil

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var durationTimer: Timer?
    private var currentRecordingURL: URL?

    public override init() {
        super.init()
    }

    public var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public func startRecording() {
        errorMessage = nil
        lastSavedBanner = nil

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecordingSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginRecordingSession()
                    } else {
                        self?.errorMessage = "Izin mikrofon tidak diberikan. Silakan aktifkan di Pengaturan Sistem."
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Akses mikrofon ditolak. Buka Pengaturan Sistem > Privasi & Keamanan > Mikrofon."
        @unknown default:
            errorMessage = "Gagal mengakses mikrofon."
        }
    }

    private func beginRecordingSession() {
        let storageDir = DropZoneService.shared.screenshotStorageDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileURL = storageDir.appendingPathComponent("Rekaman_\(timestamp).m4a")
        self.currentRecordingURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            durationSeconds = 0

            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.durationSeconds += 1
                }
            }

            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let avg = recorder.averagePower(forChannel: 0)
                let normalized = max(0.12, CGFloat(pow(10.0, avg / 20.0)))
                DispatchQueue.main.async {
                    var levels = self.audioLevels
                    if levels.count >= 16 {
                        levels.removeFirst()
                    }
                    levels.append(normalized)
                    self.audioLevels = levels
                }
            }
        } catch {
            errorMessage = "Gagal memulai perekam audio: \(error.localizedDescription)"
            isRecording = false
        }
    }

    public func stopAndSave() {
        guard isRecording, let recorder = audioRecorder else { return }
        isSaving = true
        meterTimer?.invalidate()
        durationTimer?.invalidate()
        recorder.stop()
        isRecording = false

        guard let fileURL = currentRecordingURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            isSaving = false
            return
        }

        // Add to Tray
        DropZoneService.shared.addURLs([fileURL])

        // Copy file to clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([fileURL as NSURL])

        NSSound(named: "Glass")?.play()

        withAnimation {
            self.lastSavedBanner = "🎙️ Rekaman tersimpan di Tray & Clipboard!"
            self.isSaving = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                if self.lastSavedBanner?.contains("Rekaman tersimpan") == true {
                    self.lastSavedBanner = nil
                }
            }
        }
    }

    public func cancel() {
        meterTimer?.invalidate()
        durationTimer?.invalidate()
        audioRecorder?.stop()
        if let fileURL = currentRecordingURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        isRecording = false
        isSaving = false
        durationSeconds = 0
    }
}
