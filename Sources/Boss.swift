import SpriteKit

/// "King Grumpcap" — the milestone boss (every 5th level). Larger than a Grumpcap,
/// takes `bossMaxHP` stomps, and telegraphs (a pause + red flash) before either
/// charging the player or lobbing a slow spore. Gravity is integrated manually in
/// GameScene (like Enemy); this class owns only the behaviour state machine, ticked
/// once per frame from GameScene.updateBoss. No SKAction moves the physics body.
final class Boss: SKSpriteNode {

    enum State { case idle, telegraph, charge, recover }
    enum Action { case none, fireProjectile }

    private(set) var state: State = .idle
    var hp = GameConfig.bossMaxHP
    var isDead = false
    var invulnerableUntil: TimeInterval = 0
    private(set) var facing: CGFloat = -1        // -1 faces left (toward an approaching player)
    private(set) var desiredVX: CGFloat = 0

    private var arenaMinX: CGFloat = 0
    private var arenaMaxX: CGFloat = 0
    private var stateTime: TimeInterval = 0
    private var cycle = 0                         // alternates charge / projectile

    // FSM durations (seconds).
    private let idleDuration: TimeInterval = 1.3
    private let telegraphDuration: TimeInterval = 0.7
    private let chargeDuration: TimeInterval = 0.75
    private let recoverDuration: TimeInterval = 1.0

    static func make(arenaMinX: CGFloat, arenaMaxX: CGFloat) -> Boss {
        let frames = Assets.framesOrPlaceholder("boss_walk", fallback: Assets.bossPlaceholder)
        let boss = Boss(texture: frames[0], color: .red, size: GameConfig.bossSpriteSize)
        boss.colorBlendFactor = 0
        boss.arenaMinX = arenaMinX
        boss.arenaMaxX = arenaMaxX
        boss.zPosition = ZLayer.enemy
        boss.configurePhysics()
        boss.setFacing(-1)
        if frames.count > 1 {
            boss.run(.repeatForever(.animate(with: frames, timePerFrame: GameConfig.enemyFrameTime,
                                             resize: false, restore: false)), withKey: "walk")
        }
        return boss
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(rectangleOf: GameConfig.bossBodySize, center: GameConfig.bossBodyCenter)
        body.allowsRotation = false
        body.affectedByGravity = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.boss
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.player
        physicsBody = body
    }

    /// Advance the behaviour one frame. Returns an action GameScene should act on
    /// (spawning a projectile needs the world + textures, so it stays there).
    func advance(dt: TimeInterval, playerX: CGFloat, now: TimeInterval) -> Action {
        guard !isDead else { desiredVX = 0; return .none }
        stateTime += dt
        var action: Action = .none

        switch state {
        case .idle:
            faceToward(playerX)
            desiredVX = facing * GameConfig.bossPatrolSpeed * 0.5   // slow stalk
            if stateTime >= idleDuration { enter(.telegraph) }

        case .telegraph:
            desiredVX = 0
            faceToward(playerX)
            // Build a red flash so the player can read the wind-up and react.
            let p = CGFloat(stateTime / telegraphDuration)
            colorBlendFactor = abs(sin(CGFloat(stateTime) * 22)) * (0.3 + 0.5 * p)
            if stateTime >= telegraphDuration {
                colorBlendFactor = 0
                if cycle % 2 == 1 { action = .fireProjectile; enter(.recover) }   // alternate behaviour
                else { enter(.charge) }
                cycle += 1
            }

        case .charge:
            desiredVX = facing * GameConfig.bossChargeSpeed
            if stateTime >= chargeDuration { enter(.recover) }

        case .recover:
            desiredVX = facing * GameConfig.bossPatrolSpeed * 0.25
            if stateTime >= recoverDuration { enter(.idle) }
        }
        return action
    }

    /// Apply a stomp. Returns true if this hit defeats the boss. `now` keeps the
    /// boss i-frames consistent with the scene clock.
    func takeHit(now: TimeInterval) -> Bool {
        guard !isDead, now >= invulnerableUntil else { return false }
        hp -= 1
        invulnerableUntil = now + GameConfig.bossHitInvulnerability
        flashWhite()
        if hp <= 0 { isDead = true; return true }
        return false
    }

    /// Keep the boss inside its arena; reverse a charge that reaches a wall.
    func clampToArena() {
        if position.x <= arenaMinX { position.x = arenaMinX; if state == .charge { setFacing(1) } }
        else if position.x >= arenaMaxX { position.x = arenaMaxX; if state == .charge { setFacing(-1) } }
    }

    func die(completion: @escaping () -> Void) {
        isDead = true
        physicsBody = nil
        removeAllActions()
        let squash = SKAction.group([.scaleY(to: 0.25, duration: 0.18), .scaleX(to: 1.3, duration: 0.18)])
        run(.sequence([squash, .fadeOut(withDuration: 0.35), .removeFromParent()])) { completion() }
    }

    // MARK: helpers

    private func enter(_ s: State) { state = s; stateTime = 0 }
    private func faceToward(_ x: CGFloat) { setFacing(x < position.x ? -1 : 1) }
    private func setFacing(_ f: CGFloat) {
        facing = f
        xScale = abs(xScale) * (f >= 0 ? 1 : -1)   // art faces right; mirror for left
    }
    private func flashWhite() {
        color = .white
        removeAction(forKey: "hitflash")
        run(.sequence([.run { [weak self] in self?.colorBlendFactor = 0.9 },
                       .wait(forDuration: 0.12),
                       .run { [weak self] in self?.colorBlendFactor = 0; self?.color = .red }]),
            withKey: "hitflash")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(texture: SKTexture?, color: UIColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)
    }
}
