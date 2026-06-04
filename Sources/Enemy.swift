import SpriteKit

/// A patrolling mushroom. Moves back and forth between two world-X bounds;
/// gravity is integrated manually in GameScene so it rests on platforms.
/// Defeated by a stomp from above.
final class Enemy: SKSpriteNode {

    var patrolMinX: CGFloat = 0
    var patrolMaxX: CGFloat = 0
    var direction: CGFloat = -1     // start walking left
    var isDead = false

    static func make(patrolMinX: CGFloat, patrolMaxX: CGFloat) -> Enemy {
        let walk = Assets.framesOrPlaceholder("grump_walk", fallback: Assets.enemyPlaceholder)
        let base = walk[0]
        let size = CGSize(width: base.size().width * GameConfig.pixelScale,
                          height: base.size().height * GameConfig.pixelScale)
        let enemy = Enemy(texture: base, color: .clear, size: size)
        enemy.patrolMinX = patrolMinX
        enemy.patrolMaxX = patrolMaxX
        enemy.configurePhysics()
        if walk.count > 1 {
            let animate = SKAction.animate(with: walk, timePerFrame: GameConfig.enemyFrameTime,
                                           resize: false, restore: false)
            enemy.run(.repeatForever(animate), withKey: "walk")
        }
        return enemy
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(rectangleOf: GameConfig.enemyBodySize,
                                 center: GameConfig.enemyBodyCenter)
        body.allowsRotation = false
        body.affectedByGravity = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.player
        physicsBody = body
        zPosition = ZLayer.enemy
    }

    /// Reverse at patrol bounds and face the travel direction (art faces right).
    func steer() {
        if position.x <= patrolMinX { direction = 1 }
        else if position.x >= patrolMaxX { direction = -1 }
        xScale = abs(xScale) * (direction >= 0 ? 1 : -1)
    }

    /// Squash-and-vanish when stomped.
    func die(completion: @escaping () -> Void) {
        isDead = true
        physicsBody = nil
        removeAction(forKey: "walk")
        let squash = SKAction.scaleY(to: 0.2, duration: 0.08)
        let fade = SKAction.fadeOut(withDuration: 0.18)
        run(.sequence([squash, fade, .removeFromParent()])) { completion() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(texture: SKTexture?, color: UIColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)
    }
}
