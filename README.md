# AI Mắt — ứng dụng camera AI cho iPhone

Ứng dụng **iOS native bằng SwiftUI, AVFoundation, Vision và Core ML**, dành cho iPhone chạy **iOS 17 trở lên**. Nhận diện ngay trên thiết bị, không cần máy chủ, tài khoản hay API trả phí. Có sẵn mô hình YOLO Tiny lượng tử hóa **8.913.366 byte** từ trang mô hình Apple và công cụ build Python không cần thư viện ngoài.

**Trạng thái bàn giao:** đã tạo mã nguồn, mô hình, project Xcode, giao diện công cụ build và workflow CI. Đã kiểm tra cấu trúc project trên Windows. **Chưa biên dịch bằng Xcode, chưa chạy camera trên iPhone thật, chưa tạo IPA có chữ ký.** Không coi đây là bản phát hành đã được kiểm định.

## Chức năng đã viết

- Xin quyền camera, đổi camera trước/sau; camera trước phản chiếu cùng hệ tọa độ với AI và ESP.
- Nhận diện vật thể bằng YOLO Tiny 80 lớp COCO, dùng Apple Vision để bám khung giữa các lần nhận diện; ID theo phiên, tên tiếng Việt và mức tin cậy.
- Tự điều chỉnh tốc độ xử lý khi máy nóng hoặc bật tiết kiệm pin; nhận diện trên ảnh RGB gốc.
- Ba chế độ ảnh: tự nhiên, nhìn đêm màu xanh tăng sáng/giảm nhiễu, tương phản trắng đen. Đèn pin cho camera sau nếu khả dụng.
- Chụp ảnh **khung hình xem trước 720p**, kèm ESP, chế độ ảnh và cảnh báo vào thư viện Ảnh. Có xem lại và chia sẻ ảnh gần nhất. Đây không phải ảnh tĩnh độ phân giải đầy đủ của cảm biến.
- Cảnh báo đỏ `WARNING` + rung khi có bằng chứng phương tiện chiếm vùng trung tâm hoặc tăng kích thước nhanh. Yêu cầu bằng chứng kéo dài để giảm cảnh báo thoáng qua, tự bỏ cảnh báo sau khi hết tín hiệu.
- Có xử lý từ chối quyền, camera bị gián đoạn, lỗi AI, khung hình hết hạn và chuyển ứng dụng ra nền.
- Giao diện tối, nút chụp lớn, nhãn VoiceOver và màn cài đặt cuộn được.

## Những giới hạn cần biết

| Yêu cầu | Khả năng thực tế của bản này |
|---|---|
| Người, xe máy, ô tô, chó, mèo | Có lớp tương ứng trong mô hình; có thể nhận sai/bỏ sót |
| Gà, vịt | Mô hình mặc định chỉ có lớp `bird`; chưa phân biệt riêng gà/vịt |
| Cây cối | Có `potted plant` cho cây trong chậu; chưa nhận diện mọi cây ngoài trời |
| Vật thể chuyển động | Theo dõi khung ngắn hạn; ID có thể đổi khi bị che, ra/vào khung hoặc giao nhau |
| Nhìn đêm | Tăng sáng số và màu xanh; vẫn cần ánh sáng, không nhìn xuyên bóng tối |
| Nhiệt độ / ảnh nhiệt | **Chưa có**. Cần camera nhiệt ngoài và SDK tương ứng; không tạo số °C giả |
| Khu vực nguy hiểm | **Không xác định được bằng camera đơn thuần**. Hiện dùng quy tắc phương tiện trong khung, không có bản đồ/vùng địa lý nguy hiểm |
| Cảnh báo hết khi tránh xa | Tắt sau khoảng 1,8 giây không còn tín hiệu hình ảnh; không đo được việc bạn đã ra khỏi một khu vực địa lý |
| ESP | Khung 2D trên vật thể trong ảnh; không nhìn xuyên vật cản, không suy ra danh tính |

Mô hình và API tham khảo: [Core ML Models của Apple](https://developer.apple.com/machine-learning/models/), [Vision Object Tracking](https://developer.apple.com/documentation/vision/vntrackobjectrequest).

## Sử dụng công cụ build

### Trên máy Windows hiện tại

Mở `Build-AIMat.cmd`, hoặc chạy:

```powershell
python scripts/builder_ui.py
```

Bảng điều khiển có các nút **Chuẩn bị**, **Kiểm tra**, **Gói mã nguồn**, **Build IPA có ký**. Windows chuẩn bị/đóng gói được mã nguồn; nút build IPA sẽ giải thích yêu cầu macOS. Không cần nhập Apple Team ID để chuẩn bị hoặc đóng gói.

```powershell
python scripts/build.py check
python scripts/build.py source
```

Gói chia sẻ nằm tại `dist/AIMat-source.zip`. Gói chỉ lấy những file thuộc dự án, không chứa chứng chỉ ký hay thư mục công cụ kiểm tra tạm.

### Trên Mac — chạy trực tiếp trên iPhone

1. Cài Xcode và Python 3; nếu dùng giao diện Python, cần bản Python có Tkinter. Công cụ dòng lệnh không cần Tkinter.
2. Giải nén dự án; mở `AIMat.xcodeproj` trong Xcode.
3. Trong **Signing & Capabilities**, chọn **Team** và đổi **Bundle Identifier** thành ID riêng, ví dụ `vn.tenban.aimat`.
4. Cắm iPhone, chọn thiết bị thật; bật Developer Mode nếu iOS yêu cầu; nhấn **Run**.
5. Nhấn **Bắt đầu quan sát**, cho phép Camera. Khi chụp lần đầu, cho phép thêm ảnh.

Không có khóa/chứng chỉ cá nhân nào được cung cấp sẵn trong dự án. Khả năng cài đặt phụ thuộc loại tài khoản Apple và provisioning bạn sử dụng.

### Tạo IPA có chữ ký trên Mac

Đăng nhập tài khoản phát triển trong Xcode và thiết lập signing hợp lệ, rồi chạy:

```bash
python3 scripts/build.py ipa --team YOURTEAMID --bundle-id vn.tenban.aimat
```

`YOURTEAMID` là mã Team 10 ký tự của bạn. Kết quả ở `build/ipa/`. Mặc định xuất cho **debugging**; có thể chọn `--method release-testing` hoặc `--method app-store-connect` nếu tài khoản/provisioning đáp ứng. Công cụ chỉ xuất file, **không tự xuất bản hoặc gửi lên App Store**.

Cũng có thể mở bảng điều khiển bằng `python3 scripts/builder_ui.py`. Nếu mở file `.command` bị thiếu quyền thực thi sau khi giải nén, chạy `bash Build-AIMat.command`.

Quy trình ký và phân phối theo [hướng dẫn Apple](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

### Build qua GitHub Actions khi chỉ có Windows

1. Đưa dự án này vào repository GitHub của bạn, bao gồm `.github/workflows/ios.yml` và mô hình `.mlmodel`.
2. Vào **Actions → Build AI Mat iOS → Run workflow**.
3. Workflow chạy kiểm tra, `swift test`, build simulator và build IPA thiết bị trên macOS.
4. Nếu toàn bộ bước thành công, tải artifact **AIMat-unsigned-IPA**.

**IPA trong artifact chưa ký, chưa cài trực tiếp được lên iPhone.** Workflow này không lưu chứng chỉ hoặc tài khoản Apple; muốn có IPA cài được cần ký hợp lệ bằng tài khoản của bạn. Workflow mới được chuẩn bị, chưa được chạy trong lần bàn giao này. GitHub có thể tính thời gian macOS runner theo gói tài khoản.

## Kiểm tra

```bash
python3 scripts/build.py prepare   # Kiểm tra mô hình, tạo lại project và kiểm tra cấu trúc
python3 scripts/build.py check     # Chạy kiểm tra cấu trúc, hash, plist và tham chiếu
swift test                        # Kiểm tra logic tọa độ, ID và cảnh báo (cần Swift)
python3 scripts/build.py simulator # Biên dịch app iOS (cần Xcode/macOS)
```

Project `.xcodeproj` được tạo bởi `scripts/generate_project.py`, không phụ thuộc CocoaPods, npm hoặc XcodeGen. Chạy lại script khi thêm/bớt file Swift; sửa build settings lâu dài trong script để tránh bị ghi đè khi tạo lại project.

Chi tiết kiểm thử và những phần chưa xác minh: [docs/TESTING.md](docs/TESTING.md). Thiết kế và luồng dữ liệu: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Mở rộng nhận diện

Để nhận diện riêng gà, vịt và cây ngoài trời, cần bộ ảnh có nhãn và mô hình object detection được huấn luyện cho các lớp đó. Bổ sung vài tên trong từ điển không tạo thêm khả năng nhận diện. Thay mô hình trong `VisionEngine` bằng Core ML detector tương thích Vision, trả về `VNRecognizedObjectObservation`; cập nhật tên tài nguyên và script đóng gói tương ứng.

Ảnh nhiệt thật cần cảm biến ngoài, giao thức/SDK của nhà sản xuất, căn chỉnh tọa độ RGB–nhiệt và kiểm thử độ chính xác. Bản này chỉ hiển thị trạng thái chưa có cảm biến, chưa chứa adapter phần cứng.
