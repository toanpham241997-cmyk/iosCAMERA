# Kiểm thử và trạng thái xác minh

Kết quả trong lần bàn giao ngày 02/11/2026:

- **Qua 25 kiểm tra cấu trúc** bằng `scripts/verify.py`, bao gồm hash của mô hình Apple đã đóng gói.
- **13 file Swift không có lỗi phân tích cú pháp** bằng tree-sitter Swift cục bộ. Đây không phải kiểm tra kiểu hoặc biên dịch bằng Swift compiler.
- Đã khởi tạo bảng điều khiển Tkinter và chạy luồng nút **Kiểm tra** tới trạng thái **Hoàn tất** bằng kiểm thử chương trình. Công cụ điều khiển Windows không truy cập được cửa sổ này để chụp/kiểm tra hình thức trực quan.
- Đã xác nhận lệnh xuất IPA trên Windows dừng và giải thích yêu cầu macOS/Xcode.
- **Chưa chạy** `swift test`, Xcode build/archive, CI trên GitHub hoặc camera trên iPhone thật. Chưa có IPA có chữ ký.

## Có thể chạy trên Windows

`python scripts/build.py check` kiểm tra plist quyền truy cập, privacy manifest, SHA-256 mô hình, tính toàn vẹn tham chiếu Xcode, tài nguyên, icon RGB 1024px, cú pháp Python và sự hiện diện của bộ test Swift.

Các kiểm tra này **không thay thế biên dịch Swift** và không chứng minh camera/AI chạy đúng trên iOS.

## Bộ test Swift

`swift test` chạy các trường hợp trong `Tests/CoreTests.swift`:

1. Aspect-fit letterboxing và đảo trục Y từ Vision.
2. Từ chối box NaN/ngoài ảnh, chặn tọa độ vào biên ảnh.
3. Giữ ID giữa lần detect, không gán cùng ID cho hai box, không gộp khác lớp.
4. Cảnh báo cần thời gian duy trì, giữ qua khoảng mất tín hiệu ngắn và tự tắt.
5. Không cảnh báo chỉ vì thấy người, confidence thấp hoặc phương tiện ngoài vùng.
6. Tracker drift không tạo cảnh báo mới.
7. Tắt cảnh báo reset ngay trong logic.
8. Mất tín hiệu/đổi ID không được cộng dồn thời gian xác nhận.
9. Phương tiện tăng diện tích đủ nhanh có thể phát cảnh báo tham khảo.

**Chưa chạy bộ test Swift tại thời điểm tạo dự án vì máy Windows hiện tại không có Swift/Xcode.** Workflow macOS đã cấu hình để chạy test và biên dịch app; chưa kích hoạt workflow trên repository.

## Kiểm thử bắt buộc trước khi phát hành

| Tình huống | Điều cần quan sát |
|---|---|
| Cho phép / từ chối camera | Không crash; có hướng dẫn Mở Cài đặt / Thử lại |
| Từ chối thêm ảnh | Báo không lưu được; vẫn có thể xem/chia sẻ ảnh vừa chụp |
| Camera trước / sau | Ảnh đúng chiều, ESP khớp trái/phải và mép box |
| Người đang đi / chó / xe máy | Box bám được trong đủ sáng; kiểm tra ID lúc giao nhau/che khuất |
| Gà/vịt/cây ngoài trời | Không tuyên bố có phân lớp riêng; kiểm tra khả năng bỏ sót |
| Chuyển chế độ nhìn đêm | Màu xanh hiển thị và ảnh lưu giống nhau; AI vẫn dùng RGB gốc |
| Chụp ảnh | Cùng box, màu chế độ, banner và footer; quyền Photos chỉ add-only |
| Phương tiện trung tâm | Cảnh báo đỏ sau dwell; vật thể đi khỏi vùng → hết sau releaseDelay |
| Quay/rung camera nhanh | Đánh giá cảnh báo nhầm; không quảng cáo phát hiện nguy hiểm chắc chắn |
| Mất stream/khóa máy/cuộc gọi | Bỏ ESP quá hạn; dừng camera/đèn; có thể khôi phục khi quay lại |
| 10–20 phút sử dụng | Đo pin, RAM, nhiệt, inference latency và frame pacing |
| Màn hình nhỏ / chữ rất lớn | Không cắt nút chụp/cài đặt; có thể cuộn đến mọi chức năng |
| VoiceOver / Reduce Motion | Nút có nhãn; cảnh báo đọc khi bắt đầu; không lặp thông báo mỗi frame |
| Không có mô hình/mô hình lỗi | Thông báo giảm khả năng, dùng fallback người/chó/mèo khi có thể |

Chỉ xem build là sẵn sàng phát hành sau khi `swift test`, Xcode build/archive và các bài kiểm tra thiết bị cần thiết đều qua. Không có số đo độ chính xác, FPS bảo đảm hay nhiệt độ giả trong tài liệu.
