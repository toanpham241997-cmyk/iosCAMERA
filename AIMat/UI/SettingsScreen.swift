import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var model: CameraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Nhận diện & ESP") {
                    Toggle("Hiện khung ESP", isOn: $model.settings.esp)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Ngưỡng tin cậy")
                            Spacer()
                            Text("\(Int(model.settings.confidence * 100))%").foregroundStyle(Palette.mint).monospacedDigit()
                        }
                        Slider(value: $model.settings.confidence, in: 0.3...0.85, step: 0.05)
                            .accessibilityLabel("Ngưỡng tin cậy nhận diện")
                        Text("Ngưỡng cao giảm nhận nhầm, nhưng có thể bỏ sót vật thể.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Cảnh báo phương tiện", isOn: $model.settings.warnings)
                    Toggle("Phản hồi rung", isOn: $model.haptics)
                    Text("Cảnh báo đỏ khi phương tiện chiếm vùng trung tâm hoặc khung của nó lớn nhanh, duy trì ít nhất 0,65 giây. Cảnh báo tự tắt khoảng 1,8 giây sau khi hết tín hiệu. Camera di chuyển cũng có thể gây cảnh báo nhầm.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Không xác định khu vực nguy hiểm, tội phạm, người nguy hiểm hoặc khoảng cách thực. Không dùng thay cho quan sát trực tiếp.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Cảnh báo tham khảo") }
                Section("Chế độ nhìn đêm") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tăng sáng: +\(model.settings.gain, specifier: "%.1f") EV")
                        Slider(value: $model.settings.gain, in: 0...2.5, step: 0.1)
                            .accessibilityLabel("Tăng sáng chế độ đêm")
                    }
                    Text("Lọc màu xanh, tăng phơi sáng số và giảm nhiễu. Cần có ánh sáng môi trường hoặc đèn pin; không nhìn được trong tối hoàn toàn. Đây không phải chế độ Night Mode chụp nhiều khung của ứng dụng Camera Apple.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Nhiệt độ & cảm biến") {
                    Label("Chưa có cảm biến nhiệt ngoài", systemImage: "thermometer.medium").foregroundStyle(Palette.secondary)
                    Text("Camera RGB và LiDAR của iPhone không cung cấp ảnh nhiệt bức xạ. Muốn đo °C theo vật thể cần camera nhiệt tương thích và SDK của nhà sản xuất; bản này chưa tích hợp phần cứng đó. Ứng dụng không tạo số nhiệt độ giả.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Khả năng của AI") {
                    Label(model.modelName, systemImage: "cpu")
                    Text("Mô hình mặc định: 80 lớp COCO, có người, xe máy, ô tô, chó, mèo, chim và cây trong chậu. Gà/vịt có thể nằm trong lớp chim; không có phân loại gà/vịt riêng hay khung nhận diện cây ngoài trời. Mô hình có thể nhận sai hoặc bỏ sót.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("ID # chỉ dùng để theo dõi ngắn hạn trong phiên camera. Không nhận diện danh tính hay khuôn mặt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Riêng tư") {
                    Label("Không tài khoản · Không máy chủ · Không quảng cáo", systemImage: "lock.shield")
                    Text("Ứng dụng không gửi ảnh lên Internet. Chỉ xin quyền Camera và quyền thêm ảnh khi bạn chụp. Ảnh chụp lưu trong thư viện Ảnh; bản xem gần nhất nằm trong bộ nhớ của phiên ứng dụng.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Mở cài đặt quyền ứng dụng") { model.openSettings() }.frame(minHeight: 44)
                }
                Section { Text("AI Mắt 1.0 · iOS 17 trở lên").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Điều chỉnh AI")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct WelcomeScreen: View {
    var onContinue: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "viewfinder").font(.system(size: 68, weight: .ultraLight)).foregroundStyle(Palette.mint).padding(.top, 44)
                Text("Thế giới trước mắt.\nThêm một góc nhìn.").font(.largeTitle.bold())
                Text("AI Mắt biến camera iPhone thành công cụ quan sát với nhận diện vật thể và khung ESP theo chuyển động.")
                    .foregroundStyle(Palette.secondary)
                feature("cpu", "AI ngay trên iPhone", "Xử lý ảnh tại máy. Không cần tài khoản.")
                feature("moon.stars", "Nhìn đêm màu xanh", "Tăng sáng hình ảnh; không đo nhiệt độ.")
                feature("exclamationmark.triangle", "Cảnh báo có giải thích", "Tín hiệu hình ảnh tham khảo, không bảo đảm an toàn.")
                Button(action: onContinue) {
                    HStack { Text("Bắt đầu quan sát").fontWeight(.semibold); Spacer(); Image(systemName: "arrow.right") }
                        .padding(18).foregroundStyle(.black).background(Palette.mint, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
                Text("Tiếp theo, iPhone sẽ hỏi quyền sử dụng camera. Chỉ khi bạn chụp ảnh, ứng dụng mới hỏi quyền thêm ảnh vào thư viện.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }.padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Palette.background).preferredColorScheme(.dark)
    }
    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(Palette.mint).frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.secondary)
            }
        }
    }
}

struct PhotoReview: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Ảnh vừa chụp kèm khung ESP")
                Button { sharing = true } label: {
                    Label("Chia sẻ ảnh", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.borderedProminent).foregroundStyle(.black)
            }.padding().background(Palette.background)
                .navigationTitle("Ảnh vừa chụp").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }.sheet(isPresented: $sharing) { ShareSheet(image: image) }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    var image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
