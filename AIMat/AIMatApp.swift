import SwiftUI

@main
struct AIMatApp: App {
    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .preferredColorScheme(.dark)
                .tint(Palette.mint)
        }
    }
}
