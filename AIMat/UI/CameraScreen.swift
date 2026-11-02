import SwiftUI

@MainActor
struct CameraScreen: View {
    @StateObject private var model = CameraViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showSettings = false
    @State private var showPhoto = false
    @State private var showWelcome = true

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    header
                    status
                    viewfinder
                        .frame(height: max(280, min(geometry.size.height - 315, 570)))
                    modePicker
                    controls
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
        }
        .sheet(isPresented: $showSettings) { SettingsScreen(model: model) }
        .sheet(isPresented: $showPhoto) {
            if let image = model.lastPhoto { PhotoReview(image: image) }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeScreen {
                showWelcome = false
                Task { await model.activate() }
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !showWelcome { Task { await model.activate() } }
            else if phase != .active { model.deactivate() }
        }
        .alert("Ảnh chụp", isPresented: Binding(get: { model.photoMessage != nil }, set: { if !$0 { model.photoMessage = nil } })) {
            Button("Đóng", role: .cancel) { model.photoMessage = nil }
            Button("Xem ảnh") { model.photoMessage = nil; showPhoto = true }
        } message: { Text(model.photoMessage ?? "") }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder").font(.system(size: 28, weight: .medium)).foregroundStyle(Palette.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI MẮT").font(.system(.title3, design: .rounded).weight(.bold)).tracking(3)
                    Text("NHÌN RÕ HƠN").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Palette.secondary)
                }
            }.accessibilityElement(children: .combine)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3)
                    .frame(width: 48, height: 48).background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            }.foregroundStyle(.white).accessibilityLabel("Cài đặt nhận diện")
        }
    }

    private var status: some View {
        HStack(spacing: 8) {
            Circle().fill(model.running ? Palette.mint : Palette.secondary).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(model.running ? "ĐANG QUAN SÁT" : model.starting ? "ĐANG KHỞI ĐỘNG" : "CAMERA TẠM DỪNG")
                .font(.system(.caption2, design: .monospaced).weight(.medium))
            Spacer(minLength: 4)
            Label("Trên thiết bị", systemImage: "lock.shield").font(.caption2).foregroundStyle(Palette.secondary)
        }.foregroundStyle(model.running ? Palette.mint : Palette.secondary)
    }

    private var viewfinder: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let frame = model.frame {
                    let rect = BoxGeometry.imageRect(image: frame.image.size, canvas: geometry.size)
                    Image(uiImage: frame.image).resizable().scaledToFit()
                        .accessibilityLabel("Hình ảnh camera \(model.isFront ? "trước" : "sau")")
                    if model.settings.esp {
                        ESPOverlay(objects: frame.objects, warningIDs: frame.hazard.objectIDs, imageRect: rect)
                    }
                    if model.settings.warnings {
                        let zone = BoxGeometry.displayRect(CGRect(x: 0.23, y: 0.08, width: 0.54, height: 0.80), inside: rect)
                        RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                            .frame(width: zone.width, height: zone.height).position(x: zone.midX, y: zone.midY)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    VStack {
                        HStack(alignment: .top) {
                            Text(model.isFront ? "FRONT / 01" : "REAR / 01").font(.system(.caption2, design: .monospaced))
                                .padding(8).background(.black.opacity(0.85), in: Capsule())
                            Spacer()
                            Text("\(frame.objects.count) VẬT THỂ").font(.system(.caption2, design: .monospaced).weight(.semibold))
                                .foregroundStyle(Palette.mint).padding(8).background(.black.opacity(0.85), in: Capsule())
                        }
                        Spacer()
                        if frame.hazard.isWarning { warningBanner(frame.hazard.reason) }
                        if frame.mode == .night {
                            Label("Tăng sáng màu xanh · Không đo nhiệt độ", systemImage: "moon.stars")
                                .font(.caption2).padding(8).background(.black.opacity(0.85), in: Capsule())
                        }
                    }.padding(12)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: model.permissionDenied ? "camera.badge.ellipsis" : "viewfinder")
                            .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(Palette.mint)
                        if model.starting { ProgressView().tint(Palette.mint) }
                        Text(model.permissionDenied ? "Cho phép truy cập camera" : model.starting ? "Đang mở camera…" : "Sẵn sàng quan sát")
                            .font(.headline)
                        Text(model.permissionDenied ? "Mở Cài đặt → AI Mắt → Camera để bật quyền truy cập." : model.message ?? "Ảnh và nhận diện được xử lý trên iPhone.")
                            .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                        if !model.starting {
                            Button(model.permissionDenied ? "Mở Cài đặt" : "Thử lại") {
                                if model.permissionDenied { model.openSettings() }
                                else { Task { await model.activate() } }
                            }.buttonStyle(.borderedProminent).foregroundStyle(.black).frame(minHeight: 44)
                        }
                    }.padding(24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(model.frame?.hazard.isWarning == true ? Palette.danger : .white.opacity(0.15), lineWidth: model.frame?.hazard.isWarning == true ? 3 : 1))
        }
    }

    private func warningBanner(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("WARNING · CHÚ Ý").font(.system(.subheadline, design: .monospaced).bold())
                Text(reason).font(.caption)
            }
        }.foregroundStyle(.white).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.65, green: 0.04, blue: 0.09), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
    }

    private var modePicker: some View {
        Picker("Chế độ hình ảnh", selection: $model.settings.mode) {
            ForEach(ScanMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
        }.pickerStyle(.segmented).padding(5).background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) {
                    shutter
                    HStack(spacing: 12) { espButton; Spacer(); torchButton }
                    HStack(spacing: 12) { switchButton; Spacer(); photoButton }
                }
            } else {
                HStack(spacing: 4) {
                    espButton
                    torchButton
                    Spacer(minLength: 0)
                    shutter
                    Spacer(minLength: 0)
                    switchButton
                    photoButton
                }
            }
        }
    }

    private var espButton: some View {
        InstrumentButton(icon: model.settings.esp ? "viewfinder" : "viewfinder.circle", title: "ESP", active: model.settings.esp) {
            model.settings.esp.toggle()
        }
    }

    private var torchButton: some View {
        InstrumentButton(icon: model.torchOn ? "flashlight.on.fill" : "flashlight.off.fill", title: "Đèn", active: model.torchOn) { model.toggleTorch() }
            .disabled(model.isFront || !model.running)
            .opacity(model.isFront || !model.running ? 0.4 : 1)
    }

    private var switchButton: some View {
        InstrumentButton(icon: "arrow.triangle.2.circlepath.camera", title: "Đổi") { model.switchCamera() }
            .disabled(!model.running).opacity(model.running ? 1 : 0.4)
    }

    private var shutter: some View {
        Button { Task { await model.capture() } } label: {
            ZStack {
                Circle().stroke(Palette.mint, lineWidth: 2).frame(width: 72, height: 72)
                Circle().fill(Palette.mint).frame(width: 58, height: 58)
                if model.isSaving { ProgressView().tint(.black) }
                else { Image(systemName: "camera.fill").font(.title2).foregroundStyle(.black) }
            }
        }.buttonStyle(.plain).disabled(model.frame == nil || model.isSaving).opacity(model.frame == nil ? 0.4 : 1)
            .accessibilityLabel("Chụp và lưu ảnh kèm khung ESP")
    }

    private var photoButton: some View {
        Button { showPhoto = true } label: {
            VStack(spacing: 5) {
                if let image = model.lastPhoto {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 32, height: 26).clipShape(RoundedRectangle(cornerRadius: 5))
                } else { Image(systemName: "photo").font(.system(size: 20)) }
                Text("Ảnh").font(.caption.weight(.medium))
            }.frame(minWidth: 44, minHeight: 58)
        }.foregroundStyle(.white).disabled(model.lastPhoto == nil).opacity(model.lastPhoto == nil ? 0.4 : 1)
            .accessibilityLabel("Xem ảnh vừa chụp")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(model.modelName)
                Spacer()
                if let frame = model.frame { Text("\(frame.inferenceMS) ms").monospacedDigit() }
            }.font(.caption2).foregroundStyle(Palette.secondary)
            if let frame = model.frame, frame.constrained {
                Label("Đang giảm tốc độ để tiết kiệm pin / giảm nhiệt máy", systemImage: "battery.25").font(.caption2).foregroundStyle(.yellow)
            }
            if let issue = model.modelIssue { Text(issue).font(.caption2).foregroundStyle(.yellow) }
            if let message = model.message, model.running { Text(message).font(.caption2).foregroundStyle(.yellow) }
            Text("Cảnh báo tham khảo từ hình ảnh. Không có cảnh báo không đồng nghĩa an toàn.")
                .font(.caption2).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
