import CoreGraphics
import SpriteKit

/// Central tuning surface. Everything that affects feel lives here so it can be
/// adjusted in one place while watching the `showsPhysics` overlay.
enum GameConfig {

    // MARK: Rendering
    /// Toggle on for FPS/draw/physics overlays during development.
    static var showDebugOverlays = false

    /// Pixel-art upscale factor. All sprites use nearest-neighbour filtering so
    /// integer scales stay crisp.
    static let pixelScale: CGFloat = 3.0

    /// Native tile is 16px; on-screen tile is 16 * pixelScale.
    static let tile: CGFloat = 16 * pixelScale            // 48pt

    /// 720p 16:9 design canvas, letterbox-cropped via .aspectFill.
    static let designWidth: CGFloat = 1280
    static let designHeight: CGFloat = 720

    // MARK: Player physics (manual gravity — physicsWorld.gravity is zero)
    static let gravityAccel: CGFloat = 2600     // pt/s²
    static let moveSpeed: CGFloat = 360         // pt/s horizontal
    static let jumpVelocity: CGFloat = 1080     // pt/s initial jump
    static let stompBounce: CGFloat = 760       // pt/s bounce after a stomp
    static let maxFallSpeed: CGFloat = 1600     // terminal velocity
    static let coyoteTime: TimeInterval = 0.10  // grace after leaving a ledge
    static let jumpBuffer: TimeInterval = 0.12  // grace before landing

    /// Player collision body (points). Tuned against the showsPhysics overlay so
    /// the box wraps the fox's torso and its bottom sits at the feet.
    static let playerBodySize = CGSize(width: 52, height: 104)
    static let playerBodyCenter = CGPoint(x: 0, y: -22)

    // MARK: Enemy
    static let enemySpeed: CGFloat = 95         // pt/s patrol speed
    static let enemyBodySize = CGSize(width: 78, height: 70)
    static let enemyBodyCenter = CGPoint(x: 0, y: -30)
    /// Player center must be this far above the enemy center to count as a stomp.
    static let stompThreshold: CGFloat = 24

    // MARK: Gameplay
    static let startingLives = 3
    static let gemScore = 100
    static let stompScore = 250
    static let invulnerability: TimeInterval = 1.3

    // MARK: Animation timing
    static let runFrameTime: TimeInterval = 0.07
    static let idleFrameTime: TimeInterval = 0.16
    static let jumpFrameTime: TimeInterval = 0.08
    static let enemyFrameTime: TimeInterval = 0.13
}

/// Physics categories. Explicit bitmasks — never rely on the 0xFFFFFFFF default.
enum PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 0b000001
    static let ground: UInt32   = 0b000010
    static let enemy: UInt32    = 0b000100
    static let gem: UInt32      = 0b001000
    static let goal: UInt32     = 0b010000
    static let killZone: UInt32 = 0b100000
}

/// Draw-order layers.
enum ZLayer {
    static let sky: CGFloat = -100
    static let parallaxFar: CGFloat = -90
    static let parallaxNear: CGFloat = -70
    static let tiles: CGFloat = 0
    static let goal: CGFloat = 5
    static let gems: CGFloat = 10
    static let enemy: CGFloat = 18
    static let player: CGFloat = 20
    static let effects: CGFloat = 30
    static let hud: CGFloat = 100
    static let overlay: CGFloat = 200
}
