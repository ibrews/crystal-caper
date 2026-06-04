import SpriteKit

/// The hero. A kinematic-feel platformer body: horizontal velocity is driven
/// directly each frame and gravity is integrated manually (see GameScene), so
/// `affectedByGravity` is false and no SKActions move the physics body.
final class Player: SKSpriteNode {

    enum State { case idle, run, jump }

    private(set) var state: State = .idle
    private(set) var facingRight = true

    private var anims: [State: [SKTexture]] = [:]

    static func make() -> Player {
        let idle = Assets.framesOrPlaceholder("pip_idle", fallback: Assets.heroPlaceholder)
        let run  = Assets.framesOrPlaceholder("pip_run",  fallback: Assets.heroPlaceholder)
        let jump = Assets.framesOrPlaceholder("pip_jump", fallback: Assets.heroPlaceholder)

        let base = idle[0]
        let size = CGSize(width: base.size().width * GameConfig.pixelScale,
                          height: base.size().height * GameConfig.pixelScale)
        let player = Player(texture: base, color: .clear, size: size)
        player.anims = [.idle: idle, .run: run, .jump: jump]
        player.configurePhysics()
        player.play(.idle, force: true)
        return player
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(rectangleOf: GameConfig.playerBodySize,
                                 center: GameConfig.playerBodyCenter)
        body.allowsRotation = false
        body.affectedByGravity = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.gem
            | PhysicsCategory.goal | PhysicsCategory.killZone
        physicsBody = body
        zPosition = ZLayer.player
    }

    func face(right: Bool) {
        guard right != facingRight else { return }
        facingRight = right
        xScale = abs(xScale) * (right ? 1 : -1)
    }

    func play(_ newState: State, force: Bool = false) {
        guard force || newState != state else { return }
        state = newState
        removeAction(forKey: "anim")

        let frames = anims[newState] ?? []
        guard !frames.isEmpty else { return }
        guard frames.count > 1 else { texture = frames[0]; return }

        let timePerFrame: TimeInterval
        switch newState {
        case .run:  timePerFrame = GameConfig.runFrameTime
        case .jump: timePerFrame = GameConfig.jumpFrameTime
        case .idle: timePerFrame = GameConfig.idleFrameTime
        }

        let animate = SKAction.animate(with: frames, timePerFrame: timePerFrame,
                                       resize: false, restore: false)
        if newState == .jump {
            // Play once and hold the final airborne frame.
            run(animate, withKey: "anim")
        } else {
            run(.repeatForever(animate), withKey: "anim")
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(texture: SKTexture?, color: UIColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)
    }
}
