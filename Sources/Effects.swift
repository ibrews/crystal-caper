import SpriteKit

/// Lightweight, code-driven particle bursts. Each burst spawns a handful of
/// small sprites (one shared spark texture) that fly out, fade, and remove
/// themselves — no per-frame SKShapeNode draw-call cost.
enum Effects {

    static func burst(at point: CGPoint, in parent: SKNode,
                      color: UIColor, count: Int = 8,
                      speed: CGFloat = 140, scale: CGFloat = 2.0) {
        let tex = Assets.sparkPlaceholder()
        for i in 0..<count {
            let spark = SKSpriteNode(texture: tex)
            spark.color = color
            spark.colorBlendFactor = 1.0
            spark.position = point
            spark.zPosition = ZLayer.effects
            spark.setScale(scale)
            parent.addChild(spark)

            let angle = (CGFloat(i) / CGFloat(count)) * .pi * 2 + CGFloat(i) * 0.3
            let dist = speed * CGFloat.random(in: 0.5...1.0) * 0.3
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist + 30   // bias upward
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.45)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.45)
            let shrink = SKAction.scale(to: 0.1, duration: 0.45)
            spark.run(.sequence([.group([move, fade, shrink]), .removeFromParent()]))
        }
    }

    /// A small puff of dust at the feet (jump / land).
    static func dust(at point: CGPoint, in parent: SKNode) {
        burst(at: point, in: parent, color: UIColor(white: 0.95, alpha: 1),
              count: 5, speed: 90, scale: 1.6)
    }

    /// A floating "+score" label that drifts up and fades.
    static func popText(_ text: String, at point: CGPoint, in parent: SKNode,
                        color: UIColor = .white) {
        let label = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
        label.text = text
        label.fontSize = 30
        label.fontColor = color
        label.position = point
        label.zPosition = ZLayer.effects
        label.verticalAlignmentMode = .center
        parent.addChild(label)
        let rise = SKAction.moveBy(x: 0, y: 50, duration: 0.7)
        rise.timingMode = .easeOut
        label.run(.sequence([.group([rise, .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }
}
