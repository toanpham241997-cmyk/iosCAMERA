import SwiftUI

enum Palette {
    static let background = Color(red: 0.027, green: 0.043, blue: 0.043)
    static let panel = Color(red: 0.065, green: 0.09, blue: 0.086)
    static let mint = Color(red: 0.48, green: 1, blue: 0.75)
    static let secondary = Color(red: 0.69, green: 0.76, blue: 0.73)
    static let danger = Color(red: 1, green: 0.30, blue: 0.34)
}

struct InstrumentButton: View {
    var icon: String
    var title: String
    var active = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption.weight(.medium))
            }
            .frame(minWidth: 54, minHeight: 58)
            .foregroundStyle(active ? Palette.mint : .white)
            .padding(.horizontal, 4)
            .background(active ? Palette.mint.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(active ? "Đang bật" : "")
    }
}
