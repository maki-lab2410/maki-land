import SwiftUI
import AVFoundation
import AppKit

public struct CameraPreviewView: NSViewRepresentable {
    public let isMirrored: Bool

    public init(isMirrored: Bool) {
        self.isMirrored = isMirrored
    }

    public func makeNSView(context: Context) -> CameraHostingNSView {
        let view = CameraHostingNSView()
        view.attachPreviewLayer(CameraMirrorService.shared.previewLayer)
        CameraMirrorService.shared.updateMirror(isMirrored)
        return view
    }

    public func updateNSView(_ nsView: CameraHostingNSView, context: Context) {
        nsView.attachPreviewLayer(CameraMirrorService.shared.previewLayer)
        CameraMirrorService.shared.updateMirror(isMirrored)
    }
}

public class CameraHostingNSView: NSView {
    private weak var attachedLayer: CALayer?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func attachPreviewLayer(_ previewLayer: CALayer) {
        if previewLayer.superlayer !== self.layer {
            previewLayer.removeFromSuperlayer()
            layer?.addSublayer(previewLayer)
        }
        attachedLayer = previewLayer
        previewLayer.frame = bounds
    }

    public override func layout() {
        super.layout()
        attachedLayer?.frame = bounds
    }
}

public struct CameraMirrorView: View {
    @ObservedObject private var service = CameraMirrorService.shared
    @ObservedObject private var state = IslandState.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("🪞")
                        .font(.system(size: 13))
                    Text("Cermin Kamera")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                if service.isRunning {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5.5, height: 5.5)
                        Text("Live Webcam")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.green.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.18))
                    .clipShape(Capsule())
                }

                Spacer()

                // Close Button
                Button {
                    service.stop()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        state.isShowingCameraMirror = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            // Video Preview Area
            ZStack {
                if service.isPermissionDenied {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.orange)
                        Text("Akses Kamera Ditolak / Tidak Ditemukan")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Buka Pengaturan Sistem > Privasi & Keamanan > Kamera, lalu aktifkan izin untuk makiland.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Button("Buka Pengaturan Sistem") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    CameraPreviewView(isMirrored: service.isMirrored)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    service.isRingLightOn ? Color.white.opacity(0.85) : Color.white.opacity(0.15),
                                    lineWidth: service.isRingLightOn ? 3.5 : 1
                                )
                                .shadow(
                                    color: service.isRingLightOn ? Color.white.opacity(0.7) : Color.clear,
                                    radius: service.isRingLightOn ? 10 : 0
                                )
                        )

                    // Flash feedback overlay
                    Color.white
                        .opacity(service.flashOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            .padding(.horizontal, 12)

            // Bottom Toolbar Controls
            HStack(spacing: 8) {
                // Ring Light Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        service.isRingLightOn.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(service.isRingLightOn ? "💡" : "🕯️")
                        Text(service.isRingLightOn ? "Lampu Nyala" : "Lampu Mati")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(service.isRingLightOn ? Color.yellow.opacity(0.24) : Color.white.opacity(0.08))
                    .foregroundColor(service.isRingLightOn ? .yellow : .white.opacity(0.7))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Mirror Flip Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        service.isMirrored.toggle()
                        service.updateMirror(service.isMirrored)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("🔄")
                        Text(service.isMirrored ? "Cermin (Flip)" : "Normal")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(service.isMirrored ? Color.purple.opacity(0.24) : Color.white.opacity(0.08))
                    .foregroundColor(service.isMirrored ? Color.purple.opacity(0.9) : .white.opacity(0.7))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Photo Capture Button (Selfie)
                Button {
                    service.capturePhoto()
                } label: {
                    HStack(spacing: 4) {
                        Text("📸")
                        Text("Ambil Foto (Selfie)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4.5)
                    .background(LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Saved Banner
            if let banner = service.savedBanner {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(banner)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.25))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            service.start()
        }
        .onDisappear {
            service.stop()
        }
    }
}
