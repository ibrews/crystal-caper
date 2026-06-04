import SpriteKit

/// A scrolling parallax backdrop attached to the camera. The sky is a fixed
/// gradient; each hill band is a horizontally-tiled strip that scrolls slower
/// than the world to fake depth.
final class ParallaxBackground: SKNode {

    private let screenSize: CGSize

    private struct Band {
        let container: SKNode
        let factor: CGFloat      // 0 = locked to camera, 1 = locked to world
        let tileWidth: CGFloat
        let baseY: CGFloat
    }
    private var bands: [Band] = []

    init(screenSize: CGSize, theme: Theme) {
        self.screenSize = screenSize
        super.init()
        zPosition = ZLayer.sky
        buildSky(top: theme.skyTop, bottom: theme.skyBottom)
        // Far hills (slow) then near hills (faster) for layered depth.
        addBand(texture: Assets.hillsTexture(color: theme.hillFar, height: 200),
                factor: 0.25, baseY: -screenSize.height * 0.5 + 150)
        addBand(texture: Assets.hillsTexture(color: theme.hillNear, height: 260),
                factor: 0.5, baseY: -screenSize.height * 0.5 + 110)
    }

    private func buildSky(top: UIColor, bottom: UIColor) {
        let sky = SKSpriteNode(texture: Assets.skyTexture(top: top, bottom: bottom))
        sky.size = CGSize(width: screenSize.width + 4, height: screenSize.height + 4)
        sky.position = .zero          // camera-local centre
        sky.zPosition = ZLayer.sky
        addChild(sky)
    }

    private func addBand(texture: SKTexture, factor: CGFloat, baseY: CGFloat) {
        let scaledWidth = texture.size().width * GameConfig.pixelScale
        let scaledHeight = texture.size().height * GameConfig.pixelScale
        let container = SKNode()
        container.zPosition = factor < 0.4 ? ZLayer.parallaxFar : ZLayer.parallaxNear
        // Enough copies to cover the screen plus one tile of slack on each side.
        let copies = Int(ceil(screenSize.width / scaledWidth)) + 3
        for i in 0..<copies {
            let strip = SKSpriteNode(texture: texture)
            strip.size = CGSize(width: scaledWidth, height: scaledHeight)
            strip.anchorPoint = CGPoint(x: 0, y: 0.5)
            strip.position = CGPoint(x: CGFloat(i) * scaledWidth, y: baseY)
            container.addChild(strip)
        }
        addChild(container)
        bands.append(Band(container: container, factor: factor,
                          tileWidth: scaledWidth, baseY: baseY))
    }

    /// Reposition bands so they scroll at their depth factor as the camera moves.
    func update(cameraX: CGFloat) {
        for band in bands {
            let scroll = cameraX * band.factor
            // Wrap within one tile width; start one tile left of screen edge.
            let offset = scroll.truncatingRemainder(dividingBy: band.tileWidth)
            band.container.position.x = -screenSize.width / 2 - band.tileWidth - offset
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
