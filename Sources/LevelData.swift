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
}
