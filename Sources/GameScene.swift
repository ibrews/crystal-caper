import SpriteKit
import UIKit

/// The single gameplay scene for "Crystal Caper".
///
/// Architecture notes:
/// - World content lives under `world`; the camera owns the HUD, controls, and
///   parallax background so they stay screen-fixed.
/// - Player & enemies use **manual gravity** (physicsWorld.gravity is zero) and
///   direct velocity control for crisp platformer feel. No SKActions move a
///   physics body.
/// - Physics-world mutations (removing nodes, respawn) are deferred from the
///   contact callback to the next `update(_:)` via pending flags/queues.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    // Nodes
    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private let hud = SKNode()
    private var parallax: ParallaxBackground!
    private var player: Player!
    private var enemies: [Enemy] = []

    // HUD
    private var scoreLabel: SKLabelNode!
    private var gemLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!
    private var leftButton: SKShapeNode!
    private var rightButton: SKShapeNode!
    private var jumpButton: SKShapeNode!

    // State
    private let state = GameState()
    private var playerStart = CGPoint.zero
    private var killY: CGFloat = -200
    private var levelWidth: CGFloat = 0
    private var camMinX: CGFloat = 0, camMaxX: CGFloat = 0
    private var camMinY: CGFloat = 300, camMaxY: CGFloat = 620
    private var isGameOver = false
    private var didWin = false
    private var overlayNode: SKNode?

    // Timing
    private var lastUpdateTime: TimeInterval = 0
    private var now: TimeInterval = 0

    // Input
    private var leftKey = false, rightKey = false
    private var pendingJump = false
    private var autoPlay = false          // attract / self-test bot (env CC_AUTOPLAY=1)
    private var lastBotX: CGFloat = -1
    private var botStuckTime: CGFloat = 0
    private var touchControls: [UITouch: Control] = [:]
    private enum Control { case left, right, jump }

    // Jump assists
    private var lastGroundedTime: TimeInterval = -100
    private var lastJumpPressTime: TimeInterval = -100

    // Deferred resolution
    private var pendingGemPickups: [SKNode] = []
    private var pendingStompedEnemies: [Enemy] = []
    private var pendingHurt = false
    private var pendingPitDeath = false
    private var pendingWin = false
    private var pendingBounce = false
    private var collectedGemIDs = Set<ObjectIdentifier>()
    private var clientIdx = 0
    private var allGemsCelebrated = false
    /// Each crystal is dedicated to a real Agile Lens client (editable flavor).
    private static let clients = ["Epic Games", "Disney", "Royal Caribbean",
        "Skidmore, Owings & Merrill", "Royal Shakespeare Company", "DBOX", "Cesium",
        "Dimensional Innovations", "Cooler Screens", "Emperia", "Dan Fink Studio",
        "Agog", "Britt Design Group", "Fairworlds"]

    private var invulnerableUntil: TimeInterval = 0
    private var shakeAmount: CGFloat = 0

    // MARK: Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.40, green: 0.72, blue: 0.95, alpha: 1)
        anchorPoint = .zero
        scaleMode = .aspectFill
        isUserInteractionEnabled = true
        autoPlay = ProcessInfo.processInfo.environment["CC_AUTOPLAY"] == "1"

        physicsWorld.gravity = .zero          // manual gravity integration
        physicsWorld.contactDelegate = self

        addChild(world)
        addChild(cameraNode)
        camera = cameraNode

        parallax = ParallaxBackground(screenSize: CGSize(width: GameConfig.designWidth,
                                                         height: GameConfig.designHeight))
        cameraNode.addChild(parallax)

        buildLevel()
        spawnPlayer()
        setupCamera()
        setupHUD()
        setupControls()
        showIntro()
        startMusic()

        if let skView = self.view {
            skView.ignoresSiblingOrder = true
        }
    }

    private func buildLevel() {
        let level = LevelData.level1
        let t = GameConfig.tile
        levelWidth = CGFloat(level.widthTiles) * t
        state.totalGems = level.gems.count

        for p in level.platforms { addPlatform(p) }
        for g in level.gems {
            let pos = CGPoint(x: (CGFloat(g.col) + 0.5) * t, y: (CGFloat(g.row) + 0.5) * t)
            world.addChild(Collectibles.gem(at: pos))
        }
        for e in level.enemies {
            let enemy = Enemy.make(patrolMinX: CGFloat(e.minCol) * t,
                                   patrolMaxX: CGFloat(e.maxCol) * t)
            enemy.position = CGPoint(x: (CGFloat(e.spawnCol) + 0.5) * t,
                                     y: CGFloat(e.row) * t + enemy.size.height / 2)
            world.addChild(enemy)
            enemies.append(enemy)
        }

        // Goal flag.
        let goalPos = CGPoint(x: (CGFloat(level.goal.col) + 0.5) * t,
                              y: CGFloat(level.goal.row) * t)
        world.addChild(Collectibles.goalFlag(at: goalPos))

        // Kill plane: a wide sensor well below the level.
        killY = -2 * t
        let killZone = SKNode()
        let kzBody = SKPhysicsBody(rectangleOf: CGSize(width: levelWidth + 20 * t, height: t))
        kzBody.isDynamic = false
        kzBody.categoryBitMask = PhysicsCategory.killZone
        kzBody.collisionBitMask = PhysicsCategory.none
        kzBody.contactTestBitMask = PhysicsCategory.player
        killZone.physicsBody = kzBody
        killZone.position = CGPoint(x: levelWidth / 2, y: killY)
        world.addChild(killZone)

        playerStart = CGPoint(x: (CGFloat(level.playerStart.col) + 0.5) * t,
                              y: CGFloat(level.playerStart.row) * t)
    }

    private func addPlatform(_ p: PlatformDef) {
        let t = GameConfig.tile
        let container = SKNode()
        container.position = CGPoint(x: CGFloat(p.col) * t, y: CGFloat(p.row) * t)
        container.zPosition = ZLayer.tiles

        for ix in 0..<p.w {
            for iy in 0..<p.h {
                let isTop = (iy == p.h - 1)
                let tile = SKSpriteNode(texture: isTop ? Assets.tileSurface() : Assets.tileFill())
                tile.size = CGSize(width: t, height: t)
                tile.anchorPoint = .zero
                tile.position = CGPoint(x: CGFloat(ix) * t, y: CGFloat(iy) * t)
                container.addChild(tile)
            }
        }

        let bodySize = CGSize(width: CGFloat(p.w) * t, height: CGFloat(p.h) * t)
        let body = SKPhysicsBody(rectangleOf: bodySize,
                                 center: CGPoint(x: bodySize.width / 2, y: bodySize.height / 2))
        body.isDynamic = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.player | PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.none
        container.physicsBody = body
        world.addChild(container)
    }

    private func spawnPlayer() {
        player = Player.make()
        player.position = playerStart
        world.addChild(player)
    }

    private func setupCamera() {
        camMinX = GameConfig.designWidth / 2
        camMaxX = max(camMinX, levelWidth - GameConfig.designWidth / 2)
        let startX = min(max(playerStart.x, camMinX), camMaxX)
        cameraNode.position = CGPoint(x: startX, y: camMinY)
    }

    // MARK: HUD

    private func setupHUD() {
        hud.zPosition = ZLayer.hud
        cameraNode.addChild(hud)
        let halfW = GameConfig.designWidth / 2
        let halfH = GameConfig.designHeight / 2

        // Inset extra from the top: .aspectFill crops the design height on tall
        // (≈19.5:9) devices, so HUD must clear ~70pt of vertical safe margin.
        scoreLabel = makeLabel("SCORE 0", size: 34)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -halfW + 56, y: halfH - 116)
        hud.addChild(scoreLabel)

        // Gem icon + counter.
        let gemIcon = SKSpriteNode(texture: Assets.texture("gem", fallback: Assets.gemPlaceholder))
        gemIcon.size = CGSize(width: 36, height: 36)
        gemIcon.position = CGPoint(x: -halfW + 72, y: halfH - 166)
        hud.addChild(gemIcon)
        gemLabel = makeLabel("0/\(state.totalGems)", size: 30)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: -halfW + 98, y: halfH - 178)
        hud.addChild(gemLabel)

        livesLabel = makeLabel(hearts(state.lives), size: 38)
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.fontColor = UIColor(red: 1.0, green: 0.36, blue: 0.42, alpha: 1)
        livesLabel.position = CGPoint(x: halfW - 56, y: halfH - 116)
        hud.addChild(livesLabel)
    }

    private func makeLabel(_ text: String, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        return label
    }

    private func hearts(_ n: Int) -> String { String(repeating: "♥", count: max(0, n)) }

    private func updateHUD() {
        scoreLabel.text = "SCORE \(state.score)"
        gemLabel.text = "\(state.gemsCollected)/\(state.totalGems)"
        livesLabel.text = hearts(state.lives)
    }

    private func setupControls() {
        let halfW = GameConfig.designWidth / 2
        let halfH = GameConfig.designHeight / 2
        leftButton = makeButton(glyph: "◀", radius: 64)
        leftButton.position = CGPoint(x: -halfW + 120, y: -halfH + 120)
        rightButton = makeButton(glyph: "▶", radius: 64)
        rightButton.position = CGPoint(x: -halfW + 268, y: -halfH + 120)
        jumpButton = makeButton(glyph: "JUMP", radius: 82, fontSize: 30)
        jumpButton.position = CGPoint(x: halfW - 140, y: -halfH + 130)
        [leftButton, rightButton, jumpButton].forEach { hud.addChild($0) }
    }

    private func makeButton(glyph: String, radius: CGFloat, fontSize: CGFloat = 46) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: radius)
        button.fillColor = UIColor(white: 1, alpha: 0.16)
        button.strokeColor = UIColor(white: 1, alpha: 0.45)
        button.lineWidth = 3
        button.zPosition = ZLayer.hud
        let label = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
        label.text = glyph
        label.fontSize = fontSize
        label.fontColor = UIColor(white: 1, alpha: 0.85)
        label.verticalAlignmentMode = .center
        button.addChild(label)
        return button
    }

    private func showIntro() {
        let title = makeLabel("CRYSTAL CAPER", size: 76)
        title.position = CGPoint(x: 0, y: 96)
        title.zPosition = ZLayer.overlay
        title.alpha = 0
        cameraNode.addChild(title)
        let subtitle = makeLabel("a tiny Agile Lens adventure", size: 30)
        subtitle.position = CGPoint(x: 0, y: 46)
        subtitle.zPosition = ZLayer.overlay
        subtitle.alpha = 0
        subtitle.fontColor = UIColor(red: 0.75, green: 0.90, blue: 1.0, alpha: 1)
        cameraNode.addChild(subtitle)
        let hint = makeLabel("Collect the crystals · stomp the mushrooms · reach the flag", size: 26)
        hint.position = CGPoint(x: 0, y: 4)
        hint.zPosition = ZLayer.overlay
        hint.alpha = 0
        cameraNode.addChild(hint)
        let appear = SKAction.fadeIn(withDuration: 0.5)
        let hold = SKAction.wait(forDuration: 2.6)
        let vanish = SKAction.fadeOut(withDuration: 0.6)
        let done = SKAction.removeFromParent()
        for node in [title, subtitle, hint] { node.run(.sequence([appear, hold, vanish, done])) }
    }

    private func startMusic() {
        guard let url = Bundle.main.url(forResource: "music", withExtension: "wav") else { return }
        let music = SKAudioNode(url: url)
        music.autoplayLooped = true
        music.isPositional = false
        addChild(music)
    }

    // MARK: Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        now = currentTime
        let clampedDt = CGFloat(min(dt, 1.0 / 30.0))

        if !isGameOver && !didWin {
            resolvePending()
            if !isGameOver && !didWin {
                updatePlayer(clampedDt)
                updateEnemies(clampedDt)
                if player.position.y < killY { pendingPitDeath = true }
            }
        }
        updateCamera()
    }

    private func updatePlayer(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let grounded = isOnGround(center: bodyCenter(of: player, GameConfig.playerBodyCenter),
                                  half: GameConfig.playerBodySize)
        if grounded { lastGroundedTime = now }

        // Horizontal input — human controls, or the autopilot/attract bot.
        var goLeft = leftKey || touchControls.values.contains(.left)
        var goRight = rightKey || touchControls.values.contains(.right)
        if autoPlay {
            goLeft = false
            goRight = true
            if grounded {
                // Stuck against a wall/ledge for a beat → hop over it.
                if lastBotX >= 0 && abs(player.position.x - lastBotX) < 0.5 {
                    botStuckTime += dt
                } else {
                    botStuckTime = 0
                }
                lastBotX = player.position.x
                if autopilotShouldJump() || botStuckTime > 0.2 {
                    pendingJump = true
                    botStuckTime = 0
                }
            }
        }
        let dir: CGFloat = (goRight ? 1 : 0) - (goLeft ? 1 : 0)
        body.velocity.dx = dir * GameConfig.moveSpeed

        // Buffered + coyote jump.
        if pendingJump { lastJumpPressTime = now; pendingJump = false }
        let wantsJump = (now - lastJumpPressTime) <= GameConfig.jumpBuffer
        let canJump = grounded || (now - lastGroundedTime) <= GameConfig.coyoteTime
        var jumped = false
        if wantsJump && canJump {
            body.velocity.dy = GameConfig.jumpVelocity
            lastJumpPressTime = -100
            lastGroundedTime = -100
            jumped = true
            Effects.dust(at: footPoint(of: player), in: world)
            Audio.play("sfx_jump.wav", on: self)
        }

        // Manual gravity, with rest clamp so standing doesn't accumulate fall speed.
        if grounded && body.velocity.dy <= 0 && !jumped {
            body.velocity.dy = 0
        } else {
            body.velocity.dy = max(body.velocity.dy - GameConfig.gravityAccel * dt,
                                   -GameConfig.maxFallSpeed)
        }
        if pendingBounce {
            body.velocity.dy = GameConfig.stompBounce
            pendingBounce = false
            jumped = false
        }

        // Facing + animation state.
        if dir > 0 { player.face(right: true) }
        else if dir < 0 { player.face(right: false) }

        if !grounded {
            player.play(.jump)
        } else if dir != 0 {
            player.play(.run)
        } else {
            player.play(.idle)
        }
    }

    private func updateEnemies(_ dt: CGFloat) {
        for enemy in enemies where !enemy.isDead {
            guard let body = enemy.physicsBody else { continue }
            let grounded = isOnGround(center: bodyCenter(of: enemy, GameConfig.enemyBodyCenter),
                                      half: GameConfig.enemyBodySize)
            if grounded && body.velocity.dy <= 0 {
                body.velocity.dy = 0
            } else {
                body.velocity.dy = max(body.velocity.dy - GameConfig.gravityAccel * dt,
                                       -GameConfig.maxFallSpeed)
            }
            enemy.steer()
            body.velocity.dx = enemy.direction * GameConfig.enemySpeed
        }
    }

    private func updateCamera() {
        guard player != nil else { return }
        let targetX = min(max(player.position.x, camMinX), camMaxX)
        let targetY = min(max(player.position.y + 60, camMinY), camMaxY)
        let lerp: CGFloat = 0.16
        var nx = cameraNode.position.x + (targetX - cameraNode.position.x) * lerp
        var ny = cameraNode.position.y + (targetY - cameraNode.position.y) * lerp
        if shakeAmount > 0.2 {
            nx += CGFloat.random(in: -shakeAmount...shakeAmount)
            ny += CGFloat.random(in: -shakeAmount...shakeAmount)
            shakeAmount *= 0.84
        } else {
            shakeAmount = 0
        }
        cameraNode.position = CGPoint(x: nx, y: ny)
        parallax.update(cameraX: cameraNode.position.x)
    }

    // MARK: Ground probing

    private func bodyCenter(of node: SKNode, _ offset: CGPoint) -> CGPoint {
        CGPoint(x: node.position.x + offset.x, y: node.position.y + offset.y)
    }

    private func footPoint(of node: SKNode) -> CGPoint {
        CGPoint(x: node.position.x, y: node.position.y + GameConfig.playerBodyCenter.y
                - GameConfig.playerBodySize.height / 2 + 6)
    }

    /// Two short downward rays at the body's left/right edges detect ground even
    /// when standing near a ledge. Only `ground` category counts.
    private func isOnGround(center: CGPoint, half: CGSize) -> Bool {
        let halfH = half.height / 2
        let halfW = half.width / 2
        for dx in [-halfW * 0.6, halfW * 0.6] {
            let start = CGPoint(x: center.x + dx, y: center.y - halfH + 4)
            let end = CGPoint(x: center.x + dx, y: center.y - halfH - 8)
            var hit = false
            physicsWorld.enumerateBodies(alongRayStart: start, end: end) { b, _, _, stop in
                if b.categoryBitMask & PhysicsCategory.ground != 0 {
                    hit = true
                    stop.pointee = true
                }
            }
            if hit { return true }
        }
        return false
    }

    /// Attract-bot decision: jump when a pit opens ahead or an enemy is in range
    /// to stomp. Enough to traverse the level for self-testing and demos.
    private func autopilotShouldJump() -> Bool {
        let t = GameConfig.tile
        let feetY = player.position.y + GameConfig.playerBodyCenter.y
            - GameConfig.playerBodySize.height / 2
        let aheadX = player.position.x + t * 1.3
        var groundAhead = false
        physicsWorld.enumerateBodies(alongRayStart: CGPoint(x: aheadX, y: feetY + 6),
                                     end: CGPoint(x: aheadX, y: feetY - t * 1.4)) { b, _, _, stop in
            if b.categoryBitMask & PhysicsCategory.ground != 0 {
                groundAhead = true
                stop.pointee = true
            }
        }
        if !groundAhead { return true }
        for enemy in enemies where !enemy.isDead {
            let dx = enemy.position.x - player.position.x
            if dx > t * 0.4 && dx < t * 2.0 && abs(enemy.position.y - player.position.y) < t {
                return true
            }
        }
        return false
    }

    // MARK: Contacts (defer all world mutation to resolvePending)

    func didBegin(_ contact: SKPhysicsContact) {
        guard player != nil else { return }
        let a = contact.bodyA, b = contact.bodyB
        let playerIsA = a.categoryBitMask == PhysicsCategory.player
        let playerIsB = b.categoryBitMask == PhysicsCategory.player
        guard playerIsA || playerIsB else { return }
        let other = playerIsA ? b : a

        switch other.categoryBitMask {
        case PhysicsCategory.gem:      queueGemPickup(other.node)
        case PhysicsCategory.goal:     pendingWin = true
        case PhysicsCategory.killZone: pendingPitDeath = true
        case PhysicsCategory.enemy:    handleEnemyContact(other.node)
        default: break
        }
    }

    private func queueGemPickup(_ node: SKNode?) {
        guard let node else { return }
        let id = ObjectIdentifier(node)
        guard !collectedGemIDs.contains(id) else { return }
        collectedGemIDs.insert(id)
        pendingGemPickups.append(node)
    }

    private func handleEnemyContact(_ node: SKNode?) {
        guard let enemy = node as? Enemy, !enemy.isDead else { return }
        if now < invulnerableUntil { return }
        guard let body = player.physicsBody else { return }
        let falling = body.velocity.dy < 0
        let above = (player.position.y + GameConfig.playerBodyCenter.y)
            > (enemy.position.y + GameConfig.enemyBodyCenter.y + GameConfig.stompThreshold)
        if falling && above {
            enemy.isDead = true
            pendingStompedEnemies.append(enemy)
            pendingBounce = true
        } else {
            pendingHurt = true
        }
    }

    private func resolvePending() {
        let cyan = UIColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1)

        for gem in pendingGemPickups {
            gem.physicsBody = nil
            Effects.burst(at: gem.position, in: world, color: cyan, count: 10)
            let client = Self.clients[clientIdx % Self.clients.count]
            clientIdx += 1
            Effects.popText("💎 \(client)", at: gem.position, in: world, color: cyan)
            gem.run(.sequence([.group([.scale(to: 1.8, duration: 0.12),
                                       .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
            state.score += GameConfig.gemScore
            state.gemsCollected += 1
            Audio.play("sfx_gem.wav", on: self)
        }
        pendingGemPickups.removeAll()
        if state.gemsCollected == state.totalGems && state.totalGems > 0 && !allGemsCelebrated {
            allGemsCelebrated = true
            celebrateAllCrystals()
        }

        for enemy in pendingStompedEnemies {
            Effects.burst(at: enemy.position, in: world,
                          color: UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1), count: 10)
            Effects.popText("+\(GameConfig.stompScore)", at: enemy.position, in: world,
                            color: .white)
            state.score += GameConfig.stompScore
            shakeAmount = max(shakeAmount, 8)
            Audio.play("sfx_stomp.wav", on: self)
            enemy.die { }
        }
        if !pendingStompedEnemies.isEmpty { enemies.removeAll { $0.isDead && $0.parent == nil } }
        pendingStompedEnemies.removeAll()

        if pendingHurt { pendingHurt = false; applyHurt() }
        if pendingPitDeath { pendingPitDeath = false; pitDeath() }
        if pendingWin && !didWin { pendingWin = false; winLevel() }

        updateHUD()
    }

    // MARK: Damage / respawn / end states

    private func applyHurt() {
        guard now >= invulnerableUntil else { return }
        state.lives -= 1
        shakeAmount = max(shakeAmount, 14)
        Audio.play("sfx_hurt.wav", on: self)
        if state.lives <= 0 { gameOver(); return }
        if let body = player.physicsBody {
            body.velocity = CGVector(dx: player.facingRight ? -260 : 260, dy: 380)
        }
        startInvulnerability()
    }

    private func pitDeath() {
        state.lives -= 1
        shakeAmount = max(shakeAmount, 10)
        Audio.play("sfx_hurt.wav", on: self)
        if state.lives <= 0 { gameOver(); return }
        player.position = playerStart
        player.physicsBody?.velocity = .zero
        cameraNode.position = CGPoint(x: min(max(playerStart.x, camMinX), camMaxX),
                                      y: cameraNode.position.y)
        player.play(.idle, force: true)
        startInvulnerability()
    }

    private func startInvulnerability() {
        invulnerableUntil = now + GameConfig.invulnerability
        player.removeAction(forKey: "blink")
        let blink = SKAction.sequence([.fadeAlpha(to: 0.3, duration: 0.1),
                                       .fadeAlpha(to: 1.0, duration: 0.1)])
        let count = Int(GameConfig.invulnerability / 0.2)
        player.run(.sequence([.repeat(blink, count: count), .fadeAlpha(to: 1, duration: 0)]),
                   withKey: "blink")
    }

    /// Fireworks + bonus when every crystal in the level is collected.
    private func celebrateAllCrystals() {
        state.score += 500
        shakeAmount = max(shakeAmount, 6)
        Audio.play("sfx_win.wav", on: self)
        Effects.popText("ALL CRYSTALS!  +500",
                        at: CGPoint(x: player.position.x, y: player.position.y + 90),
                        in: world, color: .systemYellow)
        let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemGreen, .systemOrange]
        for i in 0..<6 {
            run(.sequence([.wait(forDuration: Double(i) * 0.18), .run { [weak self] in
                guard let self else { return }
                let pos = CGPoint(x: self.player.position.x + CGFloat.random(in: -320...320),
                                  y: self.player.position.y + CGFloat.random(in: 40...260))
                Effects.burst(at: pos, in: self.world,
                              color: colors.randomElement() ?? .systemYellow,
                              count: 16, speed: 240, scale: 2.6)
            }]))
        }
    }

    private func winLevel() {
        didWin = true
        Audio.play("sfx_win.wav", on: self)
        player.physicsBody?.velocity = .zero
        player.play(.idle, force: true)
        // Confetti.
        for _ in 0..<3 {
            Effects.burst(at: CGPoint(x: player.position.x, y: player.position.y + 60),
                          in: world,
                          color: [UIColor.systemPink, .systemYellow, .systemTeal].randomElement()!,
                          count: 14, speed: 220, scale: 2.5)
        }
        let bonus = state.lives * 500
        state.score += bonus
        updateHUD()
        showOverlay(title: "YOU WIN!",
                    subtitle: "Score \(state.score)   ·   Gems \(state.gemsCollected)/\(state.totalGems)   ·   Life bonus +\(bonus)",
                    flavor: "Pip brings the crystals home to Agile Lens HQ.")
    }

    private func gameOver() {
        isGameOver = true
        player.physicsBody?.velocity = .zero
        showOverlay(title: "GAME OVER", subtitle: "Score \(state.score)")
    }

    private func showOverlay(title: String, subtitle: String, flavor: String? = nil) {
        let node = SKNode()
        node.zPosition = ZLayer.overlay
        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.55),
                               size: CGSize(width: GameConfig.designWidth,
                                            height: GameConfig.designHeight))
        node.addChild(dim)
        let titleLabel = makeLabel(title, size: 92)
        titleLabel.position = CGPoint(x: 0, y: 70)
        node.addChild(titleLabel)
        let subLabel = makeLabel(subtitle, size: 32)
        subLabel.position = CGPoint(x: 0, y: 8)
        node.addChild(subLabel)
        if let flavor {
            let flavorLabel = makeLabel(flavor, size: 24)
            flavorLabel.position = CGPoint(x: 0, y: -30)
            flavorLabel.fontColor = UIColor(red: 0.75, green: 0.90, blue: 1.0, alpha: 1)
            node.addChild(flavorLabel)
        }
        let tap = makeLabel("Tap to play again", size: 30)
        tap.position = CGPoint(x: 0, y: -88)
        tap.alpha = 0.9
        tap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.7),
                                          .fadeAlpha(to: 0.9, duration: 0.7)])))
        node.addChild(tap)
        cameraNode.addChild(node)
        overlayNode = node
        node.setScale(0.7)
        node.alpha = 0
        node.run(.group([.fadeIn(withDuration: 0.3), .scale(to: 1, duration: 0.3)]))
    }

    private func restart() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.4))
    }

    // MARK: Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver || didWin {
            restart()
            return
        }
        for touch in touches {
            let control = controlAt(touch)
            touchControls[touch] = control
            if control == .jump { pendingJump = true }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // Allow sliding between the left/right pads.
            if touchControls[touch] != .jump {
                touchControls[touch] = controlAt(touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchControls[touch] = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchControls[touch] = nil }
    }

    private func controlAt(_ touch: UITouch) -> Control? {
        let p = touch.location(in: hud)
        if distance(p, jumpButton.position) <= 90 { return .jump }
        if distance(p, leftButton.position) <= 80 { return .left }
        if distance(p, rightButton.position) <= 80 { return .right }
        // Fallback: left half of screen = move toward that side, right half lower = jump.
        return p.x < 0 ? (p.x < -GameConfig.designWidth * 0.25 ? .left : .right) : .jump
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: Hardware keyboard (simulator / iPad)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isGameOver || didWin { restart(); return }
        for press in presses {
            switch press.key?.keyCode {
            case .keyboardA, .keyboardLeftArrow: leftKey = true
            case .keyboardD, .keyboardRightArrow: rightKey = true
            case .keyboardSpacebar, .keyboardW, .keyboardUpArrow: pendingJump = true
            default: super.pressesBegan(presses, with: event)
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.key?.keyCode {
            case .keyboardA, .keyboardLeftArrow: leftKey = false
            case .keyboardD, .keyboardRightArrow: rightKey = false
            default: super.pressesEnded(presses, with: event)
            }
        }
    }
}
