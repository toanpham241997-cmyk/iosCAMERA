import UIKit
import Photos

enum PhotoService {
    @MainActor
    static func compose(_ packet: FramePacket, esp: Bool) -> UIImage {
        let size = packet.image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            packet.image.draw(in: CGRect(origin: .zero, size: size))
            let context = renderer.cgContext
            let imageRect = CGRect(origin: .zero, size: size)
            if esp {
                for item in packet.objects {
                    let rect = BoxGeometry.displayRect(item.box, inside: imageRect)
                    let color = packet.hazard.objectIDs.contains(item.id) ? UIColor.systemRed : UIColor(red: 0.43, green: 1, blue: 0.73, alpha: 1)
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(3)
                    context.stroke(rect)
                    let text = "\(item.title) #\(item.id) · \(Int(item.confidence * 100))%"
                    let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 19, weight: .semibold), .foregroundColor: color]
                    let textSize = (text as NSString).size(withAttributes: attrs)
                    let label = CGRect(x: min(max(0, rect.minX), max(0, size.width - textSize.width - 16)),
                        y: max(0, rect.minY - 34), width: min(size.width, textSize.width + 16), height: 32)
                    UIColor.black.withAlphaComponent(0.85).setFill()
                    UIBezierPath(roundedRect: label, cornerRadius: 6).fill()
                    (text as NSString).draw(at: CGPoint(x: label.minX + 8, y: label.minY + 4), withAttributes: attrs)
                }
            }
            let footer = "AI MẮT · \(packet.mode.rawValue.uppercased()) · \(Date().formatted(date: .numeric, time: .shortened))"
            let note = packet.mode == .night ? "TĂNG SÁNG MÀU XANH · KHÔNG ĐO NHIỆT ĐỘ" : "NHẬN DIỆN TRÊN THIẾT BỊ · KHÔNG ĐO KHOẢNG CÁCH"
            UIColor.black.withAlphaComponent(0.85).setFill()
            context.fill(CGRect(x: 0, y: size.height - 74, width: size.width, height: 74))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: UIColor.white]
            (footer as NSString).draw(at: CGPoint(x: 18, y: size.height - 62), withAttributes: attrs)
            (note as NSString).draw(at: CGPoint(x: 18, y: size.height - 34), withAttributes: attrs)
            if packet.hazard.isWarning {
                UIColor.systemRed.setFill()
                context.fill(CGRect(x: 0, y: 0, width: size.width, height: 56))
                ("WARNING · QUAN SÁT VÀ GIỮ KHOẢNG CÁCH" as NSString).draw(at: CGPoint(x: 18, y: 16), withAttributes: attrs)
            }
        }
    }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "AIMat.Photos", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Chưa được phép lưu ảnh. Bạn vẫn có thể chia sẻ ảnh hoặc mở Cài đặt để cấp quyền thêm ảnh."])
        }
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "AIMat.Photos", code: 2, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo ảnh JPEG."])
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}
