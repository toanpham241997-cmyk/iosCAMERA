import Foundation

struct Detection: Identifiable, Equatable {
    var id: Int
    var label: String
    var confidence: Float
    /// Vision coordinates: normalized, origin at bottom left of the upright image.
    var box: CGRect
    var isTracked = false
    var growthPerSecond: Double = 0

    var title: String { ObjectLabels.vietnamese[label.lowercased()] ?? label }
    var area: Double { Double(box.width * box.height) }
}

enum ObjectLabels {
    static let vehicles: Set<String> = ["car", "motorcycle", "motorbike", "bus", "truck", "bicycle", "train", "boat"]
    static let vietnamese: [String: String] = [
        "person": "Người", "bicycle": "Xe đạp", "car": "Ô tô", "motorcycle": "Xe máy",
        "motorbike": "Xe máy", "airplane": "Máy bay", "bus": "Xe buýt", "train": "Tàu hỏa",
        "truck": "Xe tải", "boat": "Thuyền", "traffic light": "Đèn giao thông",
        "fire hydrant": "Trụ cứu hỏa", "stop sign": "Biển dừng", "parking meter": "Đồng hồ đỗ xe",
        "bench": "Ghế dài", "bird": "Chim / gia cầm", "cat": "Mèo", "dog": "Chó",
        "horse": "Ngựa", "sheep": "Cừu", "cow": "Bò", "elephant": "Voi", "bear": "Gấu",
        "zebra": "Ngựa vằn", "giraffe": "Hươu cao cổ", "backpack": "Ba lô", "umbrella": "Ô",
        "handbag": "Túi xách", "tie": "Cà vạt", "suitcase": "Va li", "frisbee": "Đĩa ném",
        "skis": "Ván trượt tuyết", "snowboard": "Ván tuyết", "sports ball": "Bóng",
        "kite": "Diều", "baseball bat": "Gậy bóng chày", "baseball glove": "Găng bóng chày",
        "skateboard": "Ván trượt", "surfboard": "Ván lướt sóng", "tennis racket": "Vợt tennis",
        "bottle": "Chai", "wine glass": "Ly rượu", "cup": "Cốc", "fork": "Nĩa", "knife": "Dao",
        "spoon": "Thìa", "bowl": "Bát", "banana": "Chuối", "apple": "Táo", "sandwich": "Sandwich",
        "orange": "Cam", "broccoli": "Bông cải", "carrot": "Cà rốt", "hot dog": "Bánh mì xúc xích",
        "pizza": "Pizza", "donut": "Bánh vòng", "cake": "Bánh", "chair": "Ghế", "couch": "Sofa",
        "sofa": "Sofa", "potted plant": "Cây trong chậu", "pottedplant": "Cây trong chậu",
        "bed": "Giường", "dining table": "Bàn ăn", "diningtable": "Bàn ăn", "toilet": "Bồn cầu",
        "tv": "TV", "tvmonitor": "TV", "laptop": "Máy tính", "mouse": "Chuột máy tính",
        "remote": "Điều khiển", "keyboard": "Bàn phím", "cell phone": "Điện thoại",
        "microwave": "Lò vi sóng", "oven": "Lò nướng", "toaster": "Máy nướng bánh",
        "sink": "Bồn rửa", "refrigerator": "Tủ lạnh", "book": "Sách", "clock": "Đồng hồ",
        "vase": "Bình hoa", "scissors": "Kéo", "teddy bear": "Gấu bông", "hair drier": "Máy sấy",
        "toothbrush": "Bàn chải", "chicken": "Gà", "duck": "Vịt", "tree": "Cây"
    ]
}

enum BoxGeometry {
    static func clamped(_ rect: CGRect) -> CGRect? {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite else { return nil }
        let clipped = rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return clipped.isNull || clipped.width <= 0 || clipped.height <= 0 ? nil : clipped
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let overlap = a.intersection(b)
        guard !overlap.isNull else { return 0 }
        let area = overlap.width * overlap.height
        let union = a.width * a.height + b.width * b.height - area
        return union > 0 ? Double(area / union) : 0
    }

    /// Aspect-fit mapping is shared by the live preview and captured ESP photos.
    static func imageRect(image: CGSize, canvas: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let scale = min(canvas.width / image.width, canvas.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    static func displayRect(_ box: CGRect, inside image: CGRect) -> CGRect {
        CGRect(x: image.minX + box.minX * image.width,
               y: image.minY + (1 - box.maxY) * image.height,
               width: box.width * image.width, height: box.height * image.height)
    }
}

/// One-to-one IoU association. IDs are session-local, never identities of people.
struct TrackAssociator {
    private var nextID = 1

    mutating func associate(_ observations: [Detection], with previous: [Detection], elapsed: Double) -> [Detection] {
        var available = Set(previous.indices)
        return observations.sorted { $0.confidence > $1.confidence }.map { observation in
            var item = observation
            let match = available.filter { previous[$0].label == item.label }
                .map { ($0, BoxGeometry.iou(previous[$0].box, item.box)) }
                .filter { $0.1 >= 0.20 }.max { $0.1 < $1.1 }
            if let (index, _) = match {
                available.remove(index)
                item.id = previous[index].id
                // Growth is measured only at detector refreshes, never tracker drift.
                let oldArea = previous[index].area
                if oldArea > 0.001, elapsed > 0.05, elapsed < 1.5 {
                    item.growthPerSecond = max(-5, min(5, (item.area / oldArea - 1) / elapsed))
                }
            } else {
                item.id = nextID
                nextID += 1
            }
            return item
        }
    }
}
