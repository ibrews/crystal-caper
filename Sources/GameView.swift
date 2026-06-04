import SwiftUI
import SpriteKit

/// SwiftUI host for the SpriteKit game. The scene is built once at a fixed
/// design resolution and scaled to the device with `.aspectFill`.
struct GameView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: GameConfig.designWidth,
                                           height: GameConfig.designHeight))
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        SpriteView(
            scene: scene,
            debugOptions: GameConfig.showDebugOverlays
                ? [.showsFPS, .showsNodeCount, .showsDrawCount, .showsPhysics]
                : []
        )
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
