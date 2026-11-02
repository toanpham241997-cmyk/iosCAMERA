# Sửa lỗi GitHub Actions ngày 02/11/2026

## Nguyên nhân và bản sửa

1. `swift test` trên runner macOS thất bại vì `Detection.swift` và `HazardEngine.swift` chỉ import `Foundation`. Những file này cần Swift overlay của **CoreGraphics** để dùng initializer, thuộc tính hình học và `Equatable` của `CGRect`. Đã thêm `import CoreGraphics` vào hai file lõi và `Tests/CoreTests.swift`.
2. `ESPOverlay.swift` có dấu ngoặc đóng sai khi tạo `Text` và gọi `context.resolve`. Đã tách caption thành biểu thức `Text` riêng, áp dụng font/màu rồi mới resolve để vẽ lên Canvas.
3. Workflow dùng các action Node.js 20 cũ. Đã cập nhật `checkout`, `setup-python` và `upload-artifact` lên major 6, dùng runtime Node.js 24. Đây là cảnh báo phụ, không phải nguyên nhân trực tiếp của lỗi `CGRect`.
4. Thêm bước in phiên bản Xcode/Swift và dùng `xcrun swift test` để chọn Swift từ Apple toolchain đang được runner sử dụng.

## Các file cần cập nhật trên GitHub

```text
AIMat/Core/Detection.swift
AIMat/Core/HazardEngine.swift
AIMat/UI/ESPOverlay.swift
Tests/CoreTests.swift
.github/workflows/ios.yml
```

Đường dẫn được giữ nguyên trong `dist/AIMat-CI-fix.zip`. Giải nén vào thư mục gốc của bản clone repository, cho phép thay thế năm file trên rồi commit/push bằng GitHub Desktop hoặc Git. Gói không chứa `.git`, mô hình AI hay chứng chỉ và không thay đổi các file khác.

Nếu cập nhật bằng giao diện web GitHub, cần cập nhật đúng đường dẫn của từng file. Thư mục `.github` có thể bị ẩn trong trình quản lý file; không bỏ sót `ios.yml`.

## Chạy lại đúng phiên bản code

Commit/push thay đổi mới sẽ kích hoạt workflow `Build AI Mat iOS`. Hoặc chọn **Actions → Build AI Mat iOS → Run workflow → main** sau khi thay đổi đã có trên `main`.

**Không chỉ bấm Re-run jobs ở run cũ**: thao tác đó chạy lại commit cũ `96d1b1b`, nên vẫn gặp code chưa sửa.

## Trạng thái xác minh

- Đã qua 25 kiểm tra cấu trúc cục bộ; mô hình đóng gói vẫn đúng SHA-256.
- Đã rà lại cách dựng nhãn ESP và import cần thiết cho ba file dùng CoreGraphics độc lập.
- Chưa xác minh `swift test` hoặc biên dịch Xcode sau bản sửa: máy hiện tại là Windows, không có Swift/Xcode.
- Kết nối GitHub từ phiên này từ chối tạo nhánh vì yêu cầu phê duyệt trong chế độ không cho phép phê duyệt. **Chưa có thay đổi nào được đẩy lên repository, chưa khởi chạy CI mới.** Chỉ xác nhận build thành công khi run của commit mới qua toàn bộ các bước.

Tham khảo: [CGGeometry của Apple](https://developer.apple.com/documentation/coregraphics/cggeometry), [checkout](https://github.com/actions/checkout), [setup-python](https://github.com/actions/setup-python), [upload-artifact](https://github.com/actions/upload-artifact).
