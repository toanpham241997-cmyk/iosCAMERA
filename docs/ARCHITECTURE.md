# Kiến trúc AI Mắt

## Luồng dữ liệu

```text
AVCaptureSession (camera trước/sau, portrait)
  └─ AVCaptureVideoDataOutput (upright, mirror camera trước)
      ├─ RGB gốc → YOLO Core ML / Apple Vision → detections
      │             └─ IoU association → VNTrackObjectRequest giữa các lần detect
      │                 └─ HazardEngine (chỉ dùng detection mới)
      └─ Core Image → tự nhiên / tăng sáng xanh / tương phản
          └─ FramePacket (ảnh + boxes + cảnh báo + timestamp)
              ├─ SwiftUI Image + ESP Canvas (aspect-fit)
              └─ PhotoService → render cùng hệ tọa độ → Photos / chia sẻ
```

`CameraService` quản lý session, Core ML, Core Image và tracking trên **một serial queue**. UI cập nhật qua main queue; không đọc/ghi model Vision đồng thời. Frame rate mục tiêu tối đa 15 Hz; phát hiện lại tối đa 4 Hz, tracking ở các frame xen kẽ. Khi low power hoặc thermal serious/critical: tối đa 8 Hz hiển thị, khoảng 1,5 Hz detect. Đây là giới hạn lập lịch, **không phải benchmark FPS thực tế**.

Chỉ giữ ảnh hiện tại, các track và ảnh chụp gần nhất trong RAM. Không video recorder, không lịch sử người, không telemetry, không truy cập mạng ở runtime. Dừng camera và tắt đèn khi scene không active. Watchdog xóa khung ESP nếu frame quá hạn 2 giây. Khi stream lỗi, UI không hiển thị trạng thái an toàn.

## Tọa độ

Ứng dụng khóa portrait. Video output xoay pixel buffer 90° và mirror ở camera trước; cả preview lẫn AI dùng cùng pixel buffer và `orientation: .up`. Vision box gốc trái dưới chuẩn hóa `[0,1]`. `BoxGeometry` chuyển sang tọa độ trái trên trong vùng ảnh aspect-fit, bao gồm letterbox. Không xoay/mirror lần thứ hai. Cần kiểm thử trên iPhone thật để xác nhận hành vi của từng thiết bị.

## Logic cảnh báo

- Lớp phương tiện: ô tô, xe máy, xe buýt, xe tải, xe đạp, tàu/thuyền.
- Tin cậy ít nhất 60%; chỉ lấy kết quả detect, không dùng khung tracker dự đoán.
- Tâm box nằm trong vùng chuẩn hóa `(x: 0.23, y: 0.08, w: 0.54, h: 0.80)`.
- Box chiếm ít nhất 18% ảnh, **hoặc** chiếm ít nhất 6% và diện tích tăng từ 45%/giây qua hai lần detect cùng ID.
- Cùng ID phải tiếp tục thỏa điều kiện ít nhất 0,65 giây.
- Sau xác nhận, giữ cảnh báo tối đa 1,8 giây từ lần có bằng chứng cuối. Nếu stream chết, watchdog bỏ toàn bộ ảnh và báo gián đoạn.
- Tắt cảnh báo trong cài đặt sẽ reset trạng thái ở lần xử lý tiếp theo.

Không sử dụng ngoại hình, danh tính hay thuộc tính cá nhân để suy ra một người nguy hiểm. Người không phải ứng viên cảnh báo. Không tạo khoảng cách, tốc độ km/h, °C hay điểm nguy hiểm không có cảm biến. Tiến/lùi/zoom camera có thể làm box lớn lên; vì vậy đây chỉ là tín hiệu chú ý.

## Thiết kế giao diện

Màu nền `#070B0B`, panel gần `#111716`, điểm nhấn mint `#7AFFBF`, chữ phụ sáng `#B0C2BA`. SF Symbols và font hệ thống để giữ app nhỏ. Giao diện chính: trạng thái → camera + ESP → chế độ ảnh → chụp/đổi/đèn → thông tin AI. Cảnh báo có cả chữ, biểu tượng và màu đỏ, không nhấp nháy. Không dùng animation gây chuyển động giả trên khung theo dõi.

Màn camera dùng vùng cuộn để không cắt nội dung trên máy nhỏ hoặc khi tăng cỡ chữ. Các phần onboarding/cài đặt/ảnh có nút hoàn tất rõ ràng. Khung Canvas ẩn khỏi VoiceOver; nút thao tác có nhãn. Các xác minh Dynamic Type/VoiceOver và bố cục thực tế còn phải chạy trên iOS.

## Mô hình và giấy phép

Nguồn: [Apple Core ML Models](https://developer.apple.com/machine-learning/models/).

Model: `YOLOv3TinyInt8LUT.mlmodel`, download URL và SHA-256 được ghi trong `model-lock.json`. Metadata mô hình ghi tác giả Joseph Redmon, Ali Farhadi; thông tin giấy phép dẫn tới [Darknet](https://github.com/pjreddie/darknet/blob/master/LICENSE). Giữ metadata và kiểm tra điều kiện sử dụng mô hình khi phân phối sản phẩm. Mã nguồn ứng dụng được tạo riêng trong workspace này, không bao gồm SDK bên thứ ba ở runtime.
