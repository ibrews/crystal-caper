import SpriteKit

/// Cached one-shot sound effects. Actions are built once and reused.
/// Silently no-ops if a sound file isn't bundled, so the game never crashes
/// on a missing asset (SKAction.playSoundFileNamed would otherwise trap).
enum Audio {
    private static var cache: [String: SKAction] = [:]

    private static func action(_ file: String) -> SKAction? {
        if let cached = cache[file] { return cached }
        let stem = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard Bundle.main.url(forResource: stem, withExtension: ext) != nil else { return nil }
        let act = SKAction.playSoundFileNamed(file, waitForCompletion: false)
        cache[file] = act
        return act
    }

    static func play(_ file: String, on node: SKNode) {
        guard let act = action(file) else { return }
        node.run(act)
    }
}
