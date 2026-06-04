import SwiftUI

/// App entry point. A single full-screen game view, landscape-locked.
@main
struct CrystalCaperApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .statusBarHidden()
        }
    }
}
