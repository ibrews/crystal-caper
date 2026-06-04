import CoreGraphics

/// Hand-authored level, expressed in tile coordinates with the origin at the
/// bottom-left. `row` is the bottom row of a block; a platform of height `h`
/// has its walkable surface at tile row `row + h`.
struct PlatformDef { let col: Int; let row: Int; let w: Int; let h: Int }
struct GemDef { let col: Int; let row: Int }
struct EnemyDef { let spawnCol: Int; let row: Int; let minCol: Int; let maxCol: Int }

struct LevelDef {
    let widthTiles: Int
    let playerStart: (col: Int, row: Int)
    let goal: (col: Int, row: Int)
    let platforms: [PlatformDef]
    let gems: [GemDef]
    let enemies: [EnemyDef]
}

enum LevelData {
    /// "Crystal Caper" — a left-to-right run with three pits, two floating
    /// step routes (the higher one rewards a precise jump with extra gems),
    /// three patrolling mushrooms, and a goal flag.
    static let level1 = LevelDef(
        widthTiles: 66,
        playerStart: (col: 2, row: 4),
        goal: (col: 60, row: 3),
        platforms: [
            PlatformDef(col: 0,  row: 0, w: 14, h: 3),   // ground A
            PlatformDef(col: 17, row: 0, w: 11, h: 3),   // ground B (after pit)
            PlatformDef(col: 20, row: 6, w: 4,  h: 1),   // floating ledge over B (3-tile clearance)
            PlatformDef(col: 31, row: 0, w: 12, h: 3),   // ground C (after pit)
            PlatformDef(col: 35, row: 6, w: 3,  h: 1),   // step 1 (3-tile clearance under)
            PlatformDef(col: 39, row: 8, w: 3,  h: 1),   // step 2 (high reward)
            PlatformDef(col: 46, row: 0, w: 20, h: 3)    // ground D — final stretch
        ],
        gems: [
            GemDef(col: 8,  row: 4), GemDef(col: 11, row: 4),
            GemDef(col: 20, row: 7), GemDef(col: 21, row: 7),
            GemDef(col: 22, row: 7), GemDef(col: 23, row: 7),
            GemDef(col: 36, row: 7), GemDef(col: 37, row: 7),
            GemDef(col: 40, row: 10), GemDef(col: 41, row: 10),
            GemDef(col: 48, row: 4), GemDef(col: 50, row: 4),
            GemDef(col: 52, row: 4), GemDef(col: 58, row: 4)
        ],
        enemies: [
            EnemyDef(spawnCol: 22, row: 3, minCol: 18, maxCol: 27),
            EnemyDef(spawnCol: 36, row: 3, minCol: 32, maxCol: 42),
            EnemyDef(spawnCol: 52, row: 3, minCol: 47, maxCol: 58)
        ]
    )

    /// Pick the level definition for level `n` (1 = hand-authored, 2+ generated).
    static func forLevel(_ n: Int) -> LevelDef { n <= 1 ? level1 : generate(level: n) }

    /// Procedurally generate level `n` (n >= 2), difficulty scaling with `n`.
    /// Mirrors the web build's `genLevel` for parity.
    static func generate(level n: Int) -> LevelDef {
        var rng = SeededRNG(seed: UInt64(7919 + n * 101))
        func r() -> Double { rng.nextDouble() }
        func ri(_ a: Int, _ b: Int) -> Int { a + Int(r() * Double(b - a + 1)) }
        let surf = 3
        var platforms: [PlatformDef] = []
        var gems: [GemDef] = []
        var enemies: [EnemyDef] = []
        var w = ri(8, 10)
        platforms.append(PlatformDef(col: 0, row: 0, w: w, h: 3))
        var col = w
        let sections = 5 + min(9, n + 2)
        let maxGap = min(5, 2 + (n >> 1))
        var enemyBudget = min(2 + n, 11)
        for _ in 0..<sections {
            let gap = ri(2, maxGap); col += gap
            w = ri(6, 10)
            platforms.append(PlatformDef(col: col, row: 0, w: w, h: 3))
            if r() < 0.85 {
                gems.append(GemDef(col: col - Int((Double(gap) / 2).rounded(.up)), row: surf + 2))
            }
            for _ in 0..<ri(1, 3) { gems.append(GemDef(col: col + ri(1, w - 2), row: surf + 1)) }
            if r() < 0.5 && w >= 5 {
                let fw = ri(2, 3), fx = col + ri(1, max(1, w - fw - 1))
                platforms.append(PlatformDef(col: fx, row: 6, w: fw, h: 1))
                for k in 0..<fw { gems.append(GemDef(col: fx + k, row: 7)) }
            }
            if enemyBudget > 0 && r() < 0.6 && w >= 5 {
                let ex = col + ri(2, w - 3)
                enemies.append(EnemyDef(spawnCol: ex, row: surf, minCol: col + 1, maxCol: col + w - 2))
                enemyBudget -= 1
            }
            col += w
        }
        col += ri(2, min(4, maxGap)); w = 8
        platforms.append(PlatformDef(col: col, row: 0, w: w, h: 3))
        return LevelDef(widthTiles: col + w + 2, playerStart: (col: 2, row: 4),
                        goal: (col: col + w - 3, row: surf),
                        platforms: platforms, gems: gems, enemies: enemies)
    }
}

/// Small seeded RNG (LCG) for reproducible procedural levels.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
