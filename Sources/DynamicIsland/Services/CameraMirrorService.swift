import Foundation
import AVFoundation
import AppKit
import SwiftUI
import CoreImage

public class CameraMirrorService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = CameraMirrorService()

    @Published public var isRunning: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var isPermissionDenied: Bool = false
    @Published public var isMirrored: Bool = true
    @Published public var isRingLightOn: Bool = true
    @Published public var flashOpacity: Double = 0.0
    @Published public var savedBanner: String? = nil

    public let session = AVCaptureSession()
    public private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private let sessionQueue = DispatchQueue(label: "com.makiland.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.makiland.camera.videoOutput")
    private let ciContext = CIContext()
    private var latestPixelBuffer: CVPixelBuffer?
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
            guard self.session.inputs.count > 0 else {
                DispatchQueue.main.async {
                    self.hasPermission = false
                    self.isPermissionDenied = true
                    self.isRunning = false
                }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                self.updateMirror(self.isMirrored)
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
        guard !isConfigured else { return }
        session.beginConfiguration()

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }

        // Pick default camera device
        if let camera = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: camera),
           session.canAddInput(input) {
            session.addInput(input)
        }

        // Setup high-performance video output for instant snapshot capture
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
        }

        session.commitConfiguration()
        isConfigured = true
    }

    public func updateMirror(_ mirrored: Bool) {
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.latestPixelBuffer = pixelBuffer
        }
    }

    // MARK: - Photo Capture

    public func capturePhoto() {
        guard session.isRunning, let pixelBuffer = latestPixelBuffer else { return }

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

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let originalImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        let finalImage = isMirrored ? flipImageHorizontally(originalImage) : originalImage

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let savedUrl = DropZoneService.shared.saveImageAsScreenshot(finalImage, prefix: "Foto_Cermin")
            if let url = savedUrl {
                DropZoneService.shared.addURLs([url])
            }

            // Copy to macOS clipboard (Cmd+V)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([finalImage])

            withAnimation {
                self.savedBanner = "📸 Foto tersimpan di Tray & Clipboard!"
            }
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
