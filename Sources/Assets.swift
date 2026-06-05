import SpriteKit
import UIKit

/// Texture loading with a procedural-placeholder fallback.
///
/// Real PixelLab art is dropped into `Resources/` as flat PNGs and loaded by
/// name (`pip_idle_0.png`, `grump_walk_0.png`, `tile_surface.png`, …). Until a
/// file exists, a hand-drawn placeholder stands in so the whole game is
/// playable and presentable from the first build.
enum Assets {

    private static var cache: [String: SKTexture] = [:]

    // MARK: Bundle loading

    /// Returns a bundled texture if a matching PNG exists, else nil.
    /// Loads via explicit file path so loose (non-asset-catalog) resource PNGs
    /// are read exactly, with nearest-neighbour filtering for crisp pixels.
    static func bundled(_ name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        cache[name] = tex
        return tex
    }

    /// Loads an ordered frame sequence: `base_0`, `base_1`, … Stops at the first gap.
    static func frames(_ base: String, max: Int = 16) -> [SKTexture] {
        var out: [SKTexture] = []
        for i in 0..<max {
            guard let tex = bundled("\(base)_\(i)") else { break }
            out.append(tex)
        }
        return out
    }

    /// Single texture with placeholder fallback.
    static func texture(_ name: String, fallback: () -> SKTexture) -> SKTexture {
        bundled(name) ?? fallback()
    }

    /// Frame sequence with a single-texture placeholder fallback.
    static func framesOrPlaceholder(_ base: String, fallback: () -> SKTexture) -> [SKTexture] {
        let f = frames(base)
        return f.isEmpty ? [fallback()] : f
    }

    // MARK: Procedural placeholder textures (cached)

    private static func cached(_ key: String, _ make: () -> SKTexture) -> SKTexture {
        if let t = cache[key] { return t }
        let t = make()
        t.filteringMode = .nearest
        cache[key] = t
        return t
    }

    private static func render(_ size: CGSize, _ draw: (CGContext, CGRect) -> Void) -> SKTexture {
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in draw(ctx.cgContext, CGRect(origin: .zero, size: size)) }
        return SKTexture(image: img)
    }

    /// Fox hero placeholder — orange body, cream belly, green scarf, dark eye.
    /// Drawn on a 68×68 canvas to match PixelLab's character canvas proportions
    /// so physics-body tuning transfers when real art lands.
    static func heroPlaceholder() -> SKTexture {
        cached("ph_hero") {
            render(CGSize(width: 68, height: 68)) { c, _ in
                // body
                c.setFillColor(UIColor(red: 0.95, green: 0.52, blue: 0.18, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 20, y: 14, width: 28, height: 40))
                // belly
                c.setFillColor(UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 27, y: 28, width: 14, height: 22))
                // ears
                c.setFillColor(UIColor(red: 0.85, green: 0.42, blue: 0.12, alpha: 1).cgColor)
                c.fill(CGRect(x: 22, y: 10, width: 8, height: 10))
                c.fill(CGRect(x: 38, y: 10, width: 8, height: 10))
                // scarf
                c.setFillColor(UIColor(red: 0.30, green: 0.72, blue: 0.36, alpha: 1).cgColor)
                c.fill(CGRect(x: 22, y: 26, width: 24, height: 6))
                // eye
                c.setFillColor(UIColor.black.cgColor)
                c.fillEllipse(in: CGRect(x: 38, y: 20, width: 5, height: 6))
                // legs
                c.setFillColor(UIColor(red: 0.40, green: 0.24, blue: 0.12, alpha: 1).cgColor)
                c.fill(CGRect(x: 26, y: 52, width: 6, height: 8))
                c.fill(CGRect(x: 36, y: 52, width: 6, height: 8))
            }
        }
    }

    /// Mushroom enemy placeholder — brown spotted cap, eyes, little feet.
    static func enemyPlaceholder() -> SKTexture {
        cached("ph_enemy") {
            render(CGSize(width: 56, height: 56)) { c, _ in
                // feet
                c.setFillColor(UIColor(red: 0.86, green: 0.78, blue: 0.62, alpha: 1).cgColor)
                c.fill(CGRect(x: 18, y: 44, width: 8, height: 8))
                c.fill(CGRect(x: 30, y: 44, width: 8, height: 8))
                // stem
                c.setFillColor(UIColor(red: 0.94, green: 0.90, blue: 0.78, alpha: 1).cgColor)
                c.fill(CGRect(x: 20, y: 30, width: 16, height: 16))
                // cap
                c.setFillColor(UIColor(red: 0.62, green: 0.34, blue: 0.20, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 10, y: 12, width: 36, height: 26))
                c.fill(CGRect(x: 10, y: 24, width: 36, height: 8))
                // spots
                c.setFillColor(UIColor(red: 0.96, green: 0.92, blue: 0.80, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 16, y: 16, width: 7, height: 7))
                c.fillEllipse(in: CGRect(x: 32, y: 18, width: 6, height: 6))
                // angry eyes
                c.setFillColor(UIColor.black.cgColor)
                c.fillEllipse(in: CGRect(x: 22, y: 33, width: 4, height: 5))
                c.fillEllipse(in: CGRect(x: 30, y: 33, width: 4, height: 5))
            }
        }
    }

    /// Boss placeholder — "King Grumpcap": a big armored mushroom with a gold
    /// crown and a furious glare. Drawn on a 96×96 canvas (vs the enemy's 56×56)
    /// so it reads as a clear, larger threat. Same hand-drawn style as the others;
    /// the loader adopts real `boss_*.png` art automatically if it's ever dropped in.
    static func bossPlaceholder() -> SKTexture {
        cached("ph_boss") {
            render(CGSize(width: 96, height: 96)) { c, _ in
                let crimson = UIColor(red: 0.58, green: 0.12, blue: 0.20, alpha: 1).cgColor
                let crimsonDark = UIColor(red: 0.44, green: 0.08, blue: 0.15, alpha: 1).cgColor
                let stem = UIColor(red: 0.93, green: 0.88, blue: 0.74, alpha: 1).cgColor
                let armor = UIColor(red: 0.34, green: 0.36, blue: 0.42, alpha: 1).cgColor
                let armorDark = UIColor(red: 0.24, green: 0.26, blue: 0.31, alpha: 1).cgColor
                let gold = UIColor(red: 0.96, green: 0.80, blue: 0.22, alpha: 1).cgColor

                // Feet.
                c.setFillColor(stem)
                c.fill(CGRect(x: 30, y: 80, width: 14, height: 12))
                c.fill(CGRect(x: 52, y: 80, width: 14, height: 12))
                // Armored shoulders / arms.
                c.setFillColor(armor)
                c.fillEllipse(in: CGRect(x: 10, y: 52, width: 20, height: 22))
                c.fillEllipse(in: CGRect(x: 66, y: 52, width: 20, height: 22))
                c.setFillColor(armorDark)
                c.fill(CGRect(x: 14, y: 60, width: 12, height: 4))
                c.fill(CGRect(x: 70, y: 60, width: 12, height: 4))
                // Stem / torso.
                c.setFillColor(stem)
                c.fill(CGRect(x: 30, y: 50, width: 36, height: 34))
                // Chest plate.
                c.setFillColor(armor)
                c.fill(CGRect(x: 34, y: 58, width: 28, height: 18))
                c.setFillColor(armorDark)
                c.fill(CGRect(x: 44, y: 58, width: 8, height: 18))
                // Cap — big crimson dome, wider than the body.
                c.setFillColor(crimson)
                c.fillEllipse(in: CGRect(x: 8, y: 22, width: 80, height: 44))
                c.fill(CGRect(x: 8, y: 44, width: 80, height: 10))
                c.setFillColor(crimsonDark)
                c.fill(CGRect(x: 8, y: 50, width: 80, height: 4))
                // Cap spots.
                c.setFillColor(UIColor(red: 0.97, green: 0.90, blue: 0.78, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 22, y: 30, width: 12, height: 12))
                c.fillEllipse(in: CGRect(x: 60, y: 32, width: 10, height: 10))
                c.fillEllipse(in: CGRect(x: 44, y: 26, width: 8, height: 8))
                // Furious eyes + angry brows.
                c.setFillColor(UIColor.white.cgColor)
                c.fillEllipse(in: CGRect(x: 34, y: 56, width: 11, height: 10))
                c.fillEllipse(in: CGRect(x: 51, y: 56, width: 11, height: 10))
                c.setFillColor(UIColor.black.cgColor)
                c.fillEllipse(in: CGRect(x: 38, y: 59, width: 5, height: 6))
                c.fillEllipse(in: CGRect(x: 53, y: 59, width: 5, height: 6))
                c.setFillColor(crimsonDark)
                c.move(to: CGPoint(x: 33, y: 54)); c.addLine(to: CGPoint(x: 46, y: 58))
                c.addLine(to: CGPoint(x: 46, y: 55)); c.addLine(to: CGPoint(x: 33, y: 51)); c.closePath(); c.fillPath()
                c.move(to: CGPoint(x: 63, y: 54)); c.addLine(to: CGPoint(x: 50, y: 58))
                c.addLine(to: CGPoint(x: 50, y: 55)); c.addLine(to: CGPoint(x: 63, y: 51)); c.closePath(); c.fillPath()
                // Crown.
                c.setFillColor(gold)
                c.fill(CGRect(x: 36, y: 12, width: 24, height: 8))
                for x in [36, 44, 52] { c.fill(CGRect(x: x, y: 4, width: 8, height: 10)) }
                c.setFillColor(UIColor(red: 0.40, green: 0.85, blue: 0.95, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 45, y: 13, width: 6, height: 6))   // crown jewel
            }
        }
    }

    /// Boss spore projectile — a small spiky purple orb.
    static func bossProjectilePlaceholder() -> SKTexture {
        cached("ph_boss_proj") {
            render(CGSize(width: 20, height: 20)) { c, _ in
                c.setFillColor(UIColor(red: 0.62, green: 0.30, blue: 0.78, alpha: 1).cgColor)
                for a in stride(from: 0.0, to: .pi * 2, by: .pi / 4) {
                    c.fill(CGRect(x: 10 + cos(a) * 8 - 1.5, y: 10 + sin(a) * 8 - 1.5, width: 3, height: 3))
                }
                c.fillEllipse(in: CGRect(x: 4, y: 4, width: 12, height: 12))
                c.setFillColor(UIColor(red: 0.85, green: 0.66, blue: 0.98, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 7, y: 7, width: 4, height: 4))
            }
        }
    }

    /// Cyan crystal gem (also used for HUD icon and sparkle particles).
    static func gemPlaceholder() -> SKTexture {
        cached("ph_gem") {
            render(CGSize(width: 24, height: 24)) { c, _ in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 12, y: 1))
                p.addLine(to: CGPoint(x: 22, y: 9))
                p.addLine(to: CGPoint(x: 12, y: 23))
                p.addLine(to: CGPoint(x: 2, y: 9))
                p.close()
                c.setFillColor(UIColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1).cgColor)
                c.addPath(p.cgPath); c.fillPath()
                // facet highlight
                c.setFillColor(UIColor(red: 0.75, green: 0.98, blue: 1.0, alpha: 1).cgColor)
                let h = UIBezierPath()
                h.move(to: CGPoint(x: 12, y: 1))
                h.addLine(to: CGPoint(x: 17, y: 9))
                h.addLine(to: CGPoint(x: 12, y: 14))
                h.addLine(to: CGPoint(x: 7, y: 9))
                h.close()
                c.addPath(h.cgPath); c.fillPath()
            }
        }
    }

    /// Small white spark used for particle bursts.
    static func sparkPlaceholder() -> SKTexture {
        cached("ph_spark") {
            render(CGSize(width: 8, height: 8)) { c, r in
                c.setFillColor(UIColor.white.cgColor)
                c.fillEllipse(in: r.insetBy(dx: 1, dy: 1))
            }
        }
    }

    /// Grass-topped dirt surface tile.
    static func tileSurface(_ name: String = "tile_surface") -> SKTexture {
        if let real = bundled(name) { return real }
        if name != "tile_surface", let forest = bundled("tile_surface") { return forest }
        return cached("ph_tile_surface") {
            render(CGSize(width: 16, height: 16)) { c, _ in
                c.setFillColor(UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
                c.setFillColor(UIColor(red: 0.36, green: 0.24, blue: 0.14, alpha: 1).cgColor)
                c.fill(CGRect(x: 3, y: 9, width: 2, height: 2))
                c.fill(CGRect(x: 10, y: 12, width: 2, height: 2))
                // grass cap
                c.setFillColor(UIColor(red: 0.34, green: 0.72, blue: 0.34, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 16, height: 5))
                c.setFillColor(UIColor(red: 0.42, green: 0.82, blue: 0.40, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 16, height: 2))
            }
        }
    }

    /// Solid dirt fill tile.
    static func tileFill(_ name: String = "tile_fill") -> SKTexture {
        if let real = bundled(name) { return real }
        if name != "tile_fill", let forest = bundled("tile_fill") { return forest }
        return cached("ph_tile_fill") {
            render(CGSize(width: 16, height: 16)) { c, _ in
                c.setFillColor(UIColor(red: 0.42, green: 0.28, blue: 0.17, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
                c.setFillColor(UIColor(red: 0.34, green: 0.22, blue: 0.13, alpha: 1).cgColor)
                c.fill(CGRect(x: 4, y: 4, width: 2, height: 2))
                c.fill(CGRect(x: 11, y: 8, width: 2, height: 2))
                c.fill(CGRect(x: 6, y: 12, width: 2, height: 2))
            }
        }
    }

    /// Wide soft sky-gradient texture for the fixed backdrop.
    static func skyTexture(top: UIColor, bottom: UIColor) -> SKTexture {
        let key = "ph_sky_\(top.hashValue)_\(bottom.hashValue)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: 4, height: 256)
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(grad, start: .zero,
                end: CGPoint(x: 0, y: size.height), options: [])
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    /// Rolling-hills silhouette band for parallax (tileable horizontally).
    static func hillsTexture(color: UIColor, height: CGFloat) -> SKTexture {
        cached("ph_hills_\(Int(height))_\(color.hashValue)") {
            let size = CGSize(width: 256, height: height)
            return render(size) { c, _ in
                c.setFillColor(color.cgColor)
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 0, y: height))
                var x: CGFloat = 0
                let step: CGFloat = 64
                p.addLine(to: CGPoint(x: 0, y: height * 0.5))
                while x < size.width {
                    p.addQuadCurve(to: CGPoint(x: x + step, y: height * 0.5),
                                   controlPoint: CGPoint(x: x + step / 2, y: height * 0.1))
                    x += step
                }
                p.addLine(to: CGPoint(x: size.width, y: height))
                p.close()
                c.addPath(p.cgPath); c.fillPath()
            }
        }
    }
}
