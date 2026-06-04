import SpriteKit

/// Factory helpers for static, sensor-bodied props (gems and the goal flag).
enum Collectibles {

    /// A spinning, bobbing crystal with a sensor body.
    static func gem(at position: CGPoint) -> SKSpriteNode {
        let tex = Assets.texture("gem", fallback: Assets.gemPlaceholder)
        let node = SKSpriteNode(texture: tex)
        node.size = CGSize(width: GameConfig.tile * 0.7, height: GameConfig.tile * 0.7)
        node.position = position
        node.zPosition = ZLayer.gems
        node.name = "gem"

        let body = SKPhysicsBody(circleOfRadius: GameConfig.tile * 0.3)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.gem
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body

        // Gentle bob + shimmer. Actions are fine here: the body is non-dynamic.
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.9),
            SKAction.moveBy(x: 0, y: -6, duration: 0.9)
        ])
        bob.timingMode = .easeInEaseOut
        node.run(.repeatForever(bob))
        let shimmer = SKAction.sequence([
            SKAction.scaleX(to: 0.7, duration: 0.7),
            SKAction.scaleX(to: 1.0, duration: 0.7)
        ])
        shimmer.timingMode = .easeInEaseOut
        node.run(.repeatForever(shimmer))
        return node
    }

    /// A checkered goal flag on a pole with a gentle wave.
    static func goalFlag(at basePosition: CGPoint) -> SKSpriteNode {
        let tex = Assets.texture("goal_flag", fallback: goalPlaceholder)
        let node = SKSpriteNode(texture: tex)
        node.size = CGSize(width: tex.size().width * GameConfig.pixelScale,
                           height: tex.size().height * GameConfig.pixelScale)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)     // stand on the ground
        node.position = basePosition
        node.zPosition = ZLayer.goal
        node.name = "goal"

        let body = SKPhysicsBody(rectangleOf: CGSize(width: GameConfig.tile * 0.5,
                                                     height: node.size.height),
                                 center: CGPoint(x: 0, y: node.size.height / 2))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.goal
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body

        let sway = SKAction.sequence([
            SKAction.rotate(byAngle: 0.04, duration: 1.0),
            SKAction.rotate(byAngle: -0.04, duration: 1.0)
        ])
        sway.timingMode = .easeInEaseOut
        node.run(.repeatForever(sway))
        return node
    }

    private static func goalPlaceholder() -> SKTexture {
        let size = CGSize(width: 28, height: 64)
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            let c = ctx.cgContext
            // pole
            c.setFillColor(UIColor(white: 0.85, alpha: 1).cgColor)
            c.fill(CGRect(x: 4, y: 0, width: 4, height: 64))
            c.setFillColor(UIColor(white: 0.5, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 1, y: 0, width: 10, height: 6))
            // checkered flag
            let cols = 4, rows = 3
            let fw = 18.0 / Double(cols), fh = 18.0 / Double(rows)
            for ix in 0..<cols {
                for iy in 0..<rows {
                    let dark = (ix + iy) % 2 == 0
                    c.setFillColor((dark ? UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1)
                                         : UIColor.white).cgColor)
                    c.fill(CGRect(x: 8 + Double(ix) * fw, y: 6 + Double(iy) * fh, width: fw, height: fh))
                }
            }
        }
        let t = SKTexture(image: img)
        t.filteringMode = .nearest
        return t
    }
}
