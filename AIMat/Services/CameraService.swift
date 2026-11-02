import AVFoundation
import UIKit
import CoreImage
import QuartzCore

enum ScanMode: String, CaseIterable, Identifiable {
    case natural = "Tự nhiên"
    case night = "Nhìn đêm"
    case contrast = "Tương phản"
    var id: Self { self }
}

struct ScanSettings {
    var mode: ScanMode = .natural
    var confidence: Float = 0.45
    var warnings = true
    var esp = true
    var gain: Float = 1.0
}

struct FramePacket {
    var image: UIImage
    var objects: [Detection]
    var hazard: HazardState
    var timestamp: Double
    var inferenceMS: Int
    var mode: ScanMode
    var constrained: Bool
}

final class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((FramePacket) -> Void)?
    var onStatus: ((Bool, String?) -> Void)?
    var onModel: ((String, String?) -> Void)?
    var onLens: ((Bool, Bool) -> Void)?

    private let queue = DispatchQueue(label: "vn.aimat.camera", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var device: AVCaptureDevice?
    private var engine: VisionEngine?
    private var settings = ScanSettings()
    private var configured = false
    private var wantsRunning = false
    private var lastFrame: Double = -10
    private var inferenceMS = 0
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
            object: session, queue: nil) { [weak self] _ in
                self?.onStatus?(false, "Camera đang bị gián đoạn. Hãy quay lại ứng dụng để tiếp tục.")
            })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
            object: session, queue: nil) { [weak self] _ in self?.resumeIfNeeded() })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
            object: session, queue: nil) { [weak self] note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                if error?.code == .mediaServicesWereReset {
                    self?.resumeIfNeeded()
                } else {
                    self?.onStatus?(false, error?.localizedDescription ?? "Lỗi camera. Hãy thử khởi động lại camera.")
                }
            })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func update(_ value: ScanSettings) {
        queue.async {
            let changed = self.settings.confidence != value.confidence || self.settings.warnings != value.warnings
            self.settings = value
            if changed { self.engine?.reset() }
            self.applyLowLight()
        }
    }

    func start() {
        queue.async {
            self.wantsRunning = true
            do {
                if self.engine == nil {
                    self.engine = VisionEngine()
                    self.onModel?(self.engine?.modelName ?? "Apple Vision", self.engine?.modelIssue)
                }
                if !self.configured { try self.configure() }
                self.engine?.reset()
                self.lastFrame = -10
                if !self.session.isRunning { self.session.startRunning() }
                self.onStatus?(self.session.isRunning, self.session.isRunning ? nil : "Chưa thể mở camera. Hãy thử lại.")
            } catch { self.onStatus?(false, error.localizedDescription) }
        }
    }

    func stop() {
        queue.async {
            self.wantsRunning = false
            self.setTorchOnQueue(false)
            if self.session.isRunning { self.session.stopRunning() }
            self.engine?.reset()
            self.onStatus?(false, nil)
        }
    }

    private func resumeIfNeeded() {
        queue.async {
            guard self.wantsRunning else { return }
            self.engine?.reset()
            self.lastFrame = -10
            if !self.session.isRunning { self.session.startRunning() }
            self.onStatus?(self.session.isRunning, nil)
        }
    }

    func switchCamera() {
        queue.async {
            guard self.configured, let current = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            let position: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
            guard let replacement = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                self.onStatus?(self.session.isRunning, "Không có camera được yêu cầu.")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: replacement)
                self.setTorchOnQueue(false)
                self.session.beginConfiguration()
                self.session.removeInput(current)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.device = replacement
                } else {
                    self.session.addInput(current)
                    self.onStatus?(self.session.isRunning, "Không thể chuyển camera.")
                }
                self.orientOutput()
                self.session.commitConfiguration()
                self.engine?.reset()
                self.lastFrame = -10
                self.applyLowLight()
                self.reportLens()
            } catch { self.onStatus?(self.session.isRunning, error.localizedDescription) }
        }
    }

    func toggleTorch() {
        queue.async { self.setTorchOnQueue(self.device?.torchMode != .on) }
    }

    private func setTorchOnQueue(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { reportLens(); return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on { try device.setTorchModeOn(level: 0.35) } else { device.torchMode = .off }
            reportLens()
        } catch { onStatus?(session.isRunning, "Không bật được đèn: \(error.localizedDescription)") }
    }

    private func reportLens() {
        onLens?(device?.position == .front, device?.torchMode == .on)
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "AIMat.Camera", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy camera. Hãy chạy trên iPhone thật."])
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw NSError(domain: "AIMat.Camera", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Thiết bị không hỗ trợ cấu hình camera này."])
        }
        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        self.device = device
        orientOutput()
        configured = true
        applyLowLight()
        reportLens()
    }

    private func orientOutput() {
        guard let connection = output.connection(with: .video) else { return }
        // This app is portrait-only. Buffers are physically upright AND mirrored here.
        // Vision and preview consume the same pixels: no second mirror or transform.
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = device?.position == .front
        }
    }

    private func applyLowLight() {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = settings.mode == .night
            }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        } catch { /* A filter still works when hardware boost is unavailable. */ }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard wantsRunning, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), let engine else { return }
        let now = CACurrentMediaTime()
        let thermal = ProcessInfo.processInfo.thermalState
        let constrained = thermal == .serious || thermal == .critical || ProcessInfo.processInfo.isLowPowerModeEnabled
        guard now - lastFrame >= (constrained ? 1.0 / 8.0 : 1.0 / 15.0) else { return }
        lastFrame = now
        autoreleasepool {
            do {
                let begin = CACurrentMediaTime()
                // Recognition sees original RGB, never the green processed display image.
                let result = try engine.process(buffer, time: now, settings: settings, constrained: constrained)
                if result.detected { inferenceMS = Int((CACurrentMediaTime() - begin) * 1000) }
                let original = CIImage(cvPixelBuffer: buffer)
                let filtered = FrameFilter.apply(original, mode: settings.mode, gain: settings.gain)
                guard let cgImage = context.createCGImage(filtered, from: original.extent) else { return }
                onFrame?(FramePacket(image: UIImage(cgImage: cgImage), objects: result.objects,
                    hazard: result.hazard, timestamp: now, inferenceMS: inferenceMS,
                    mode: settings.mode, constrained: constrained))
            } catch {
                engine.reset()
                onStatus?(false, "Nhận diện tạm dừng: \(error.localizedDescription). Chạm Thử lại.")
                wantsRunning = false
                if session.isRunning { session.stopRunning() }
            }
        }
    }
}

enum FrameFilter {
    static func apply(_ image: CIImage, mode: ScanMode, gain: Float) -> CIImage {
        switch mode {
        case .natural: return image
        case .contrast:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.6, kCIInputBrightnessKey: 0.03])
        case .night:
            let enhanced = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: gain])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.15])
                .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.03, "inputSharpness": 0.35])
            return enhanced.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.10, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.18, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
        }
    }
}
