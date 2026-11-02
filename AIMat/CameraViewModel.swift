import SwiftUI
import AVFoundation
import QuartzCore

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var frame: FramePacket?
    @Published var running = false
    @Published var authorized = false
    @Published var permissionDenied = false
    @Published var message: String?
    @Published var modelName = "Đang nạp AI trên thiết bị…"
    @Published var modelIssue: String?
    @Published var isFront = false
    @Published var torchOn = false
    @Published var settings = ScanSettings() {
        didSet { service.update(settings) }
    }
    @Published var isSaving = false
    @Published var lastPhoto: UIImage?
    @Published var photoMessage: String?
    @Published var haptics = true
    @Published var starting = false

    private let service = CameraService()
    private var watchdog: Timer?
    private var lastWarning = false
    private var active = false

    init() {
        service.onFrame = { [weak self] packet in
            DispatchQueue.main.async {
                guard let self, self.active else { return }
                self.frame = packet
                self.starting = false
                self.running = true
                if packet.hazard.isWarning && !self.lastWarning {
                    if self.haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                    UIAccessibility.post(notification: .announcement, argument: "Cảnh báo. Phương tiện trong vùng theo dõi. Quan sát và giữ khoảng cách.")
                }
                self.lastWarning = packet.hazard.isWarning
            }
        }
        service.onStatus = { [weak self] running, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.running = running && self.active
                self.starting = false
                self.message = error
                if !running { self.frame = nil; self.lastWarning = false }
            }
        }
        service.onModel = { [weak self] name, issue in
            DispatchQueue.main.async { self?.modelName = name; self?.modelIssue = issue }
        }
        service.onLens = { [weak self] front, torch in
            DispatchQueue.main.async {
                self?.isFront = front; self?.torchOn = torch
                self?.frame = nil
            }
        }
    }

    func activate() async {
        active = true
        guard !starting else { return }
        starting = true
        message = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        permissionDenied = !authorized
        guard authorized, active else { starting = false; return }
        service.update(settings)
        service.start()
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let frame = self.frame else { return }
                if CACurrentMediaTime() - frame.timestamp > 2 {
                    self.frame = nil
                    self.running = false
                    self.lastWarning = false
                    self.message = "Không nhận được khung hình mới. Hãy thử lại camera."
                }
            }
        }
    }

    func deactivate() {
        active = false
        starting = false
        watchdog?.invalidate()
        watchdog = nil
        service.stop()
        frame = nil
        running = false
        torchOn = false
        lastWarning = false
    }

    func switchCamera() {
        guard running else { return }
        frame = nil
        service.switchCamera()
    }

    func toggleTorch() { service.toggleTorch() }

    func capture() async {
        guard let frame, running, !isSaving, CACurrentMediaTime() - frame.timestamp < 1.5 else { return }
        isSaving = true
        defer { isSaving = false }
        let image = PhotoService.compose(frame, esp: settings.esp)
        lastPhoto = image
        do {
            try await PhotoService.save(image)
            photoMessage = "Đã lưu ảnh kèm ESP vào Ảnh."
            if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        } catch { photoMessage = error.localizedDescription }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
