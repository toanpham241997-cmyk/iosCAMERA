import SwiftUI

struct ESPOverlay: View {
    let objects: [Detection]
    let warningIDs: Set<Int>
    let imageRect: CGRect

    var body: some View {
        Canvas { context, size in
            for item in objects {
                let rect = BoxGeometry.displayRect(item.box, inside: imageRect)
                let color = warningIDs.contains(item.id) ? Palette.danger : Palette.mint
                let arm = min(18, min(rect.width, rect.height) * 0.25)
                var corners = Path()
                for (point, sx, sy) in [
                    (CGPoint(x: rect.minX, y: rect.minY), CGFloat(1), CGFloat(1)),
                    (CGPoint(x: rect.maxX, y: rect.minY), CGFloat(-1), CGFloat(1)),
                    (CGPoint(x: rect.minX, y: rect.maxY), CGFloat(1), CGFloat(-1)),
                    (CGPoint(x: rect.maxX, y: rect.maxY), CGFloat(-1), CGFloat(-1))
                ] {
                    corners.move(to: CGPoint(x: point.x, y: point.y + arm * sy))
                    corners.addLine(to: point)
                    corners.addLine(to: CGPoint(x: point.x + arm * sx, y: point.y))
                }
                context.stroke(Path(rect), with: .color(color.opacity(0.3)), lineWidth: 1)
                context.stroke(corners, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                let title = "\(item.title)  #\(item.id)  \(Int(item.confidence * 100))%"
                let text = context.resolve(Text(title).font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundColor(color))
                let measured = text.measure(in: CGSize(width: max(0, size.width - 16), height: 60))
                let labelWidth = min(size.width - 8, measured.width + 16)
                let label = CGRect(x: min(max(4, rect.minX), max(4, size.width - labelWidth - 4)),
                    y: max(imageRect.minY, rect.minY - measured.height - 12), width: labelWidth, height: measured.height + 10)
                context.fill(Path(roundedRect: label, cornerRadius: 5), with: .color(.black.opacity(0.9)))
                context.draw(text, in: label.insetBy(dx: 8, dy: 5))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
