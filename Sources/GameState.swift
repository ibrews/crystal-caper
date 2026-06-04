import Foundation

/// Mutable run state for a single play-through.
final class GameState {
    var score = 0
    var lives = GameConfig.startingLives
    var gemsCollected = 0
    var totalGems = 0

    func reset() {
        score = 0
        lives = GameConfig.startingLives
        gemsCollected = 0
    }
}
