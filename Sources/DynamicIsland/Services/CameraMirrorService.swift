import Foundation
import AVFoundation
import AppKit
import SwiftUI

public class CameraMirrorService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    public static let shared = CameraMirrorService()

    @Published public var isRunning: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var isPermissionDenied: Bool = false
    @Published public var isMirrored: Bool = true
    @Published public var isRingLightOn: Bool = true
    @Published public var flashOpacity: Double = 0.0
    @Published public var savedBanner: String? = nil

    public let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.makiland.camera.session")
    private var isConfigured = false

    public override init() {
        super.init()
        checkPermission()
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            isPermissionDenied = false
        case .notDetermined:
            hasPermission = false
            isPermissionDenied = false
        case .denied, .restricted:
            hasPermission = false
            isPermissionDenied = true
        @unknown default:
            hasPermission = false
            isPermissionDenied = true
        }
    }

    public func requestPermissionAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    self.hasPermission = true
                    self.isPermissionDenied = false
                    self.start()
                } else {
                    self.hasPermission = false
                    self.isPermissionDenied = true
                }
            }
        }
    }

    public func start() {
        checkPermission()
        guard hasPermission else {
            requestPermissionAndStart()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Find camera (FaceTime HD or built-in wide angle camera)
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        let camera = deviceDiscovery.devices.first ?? AVCaptureDevice.default(for: .video)

        if let camera = camera, let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        isConfigured = true
    }

    public func capturePhoto() {
        guard session.isRunning else { return }

        // Camera shutter sound & flash
        NSSound(named: "Purr")?.play()
        withAnimation(.easeIn(duration: 0.08)) {
            flashOpacity = 0.92
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.35)) {
                self.flashOpacity = 0.0
            }
        }

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let originalImage = NSImage(data: data) else {
            return
        }

        // Apply horizontal mirror if enabled
        let finalImage = isMirrored ? flipImageHorizontally(originalImage) : originalImage

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let savedUrl = DropZoneService.shared.saveImageAsScreenshot(finalImage, prefix: "Foto_Cermin")
            if let url = savedUrl {
                DropZoneService.shared.addURLs([url])
            }

            // Copy to macOS clipboard
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([finalImage])

            self.savedBanner = "📸 Foto tersimpan di Tray & Clipboard!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                if self.savedBanner?.contains("Foto tersimpan") == true {
                    withAnimation { self.savedBanner = nil }
                }
            }
        }
    }

    private func flipImageHorizontally(_ image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let flipped = NSImage(size: size)
        flipped.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        flipped.unlockFocus()
        return flipped
    }
}
