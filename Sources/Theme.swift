import UIKit

/// Per-level visual theme (cycles forest → snow → desert). Tile names map to the
/// generated PixelLab tilesets; `Assets` falls back to forest then a placeholder.
struct Theme {
    let surface: String
    let fill: String
    let skyTop: UIColor
    let skyBottom: UIColor
    let hillFar: UIColor
    let hillNear: UIColor

    static func forLevel(_ n: Int) -> Theme {
        switch (n - 1) % 3 {
        case 1: // snow
            return Theme(surface: "tile_surface_snow", fill: "tile_fill_snow",
                skyTop: UIColor(red: 0.62, green: 0.75, blue: 0.88, alpha: 1),
                skyBottom: UIColor(red: 0.91, green: 0.95, blue: 0.98, alpha: 1),
                hillFar: UIColor(red: 0.81, green: 0.88, blue: 0.92, alpha: 1),
                hillNear: UIColor(red: 0.68, green: 0.75, blue: 0.81, alpha: 1))
        case 2: // desert
            return Theme(surface: "tile_surface_desert", fill: "tile_fill_desert",
                skyTop: UIColor(red: 0.95, green: 0.71, blue: 0.42, alpha: 1),
                skyBottom: UIColor(red: 0.97, green: 0.90, blue: 0.76, alpha: 1),
                hillFar: UIColor(red: 0.88, green: 0.75, blue: 0.54, alpha: 1),
                hillNear: UIColor(red: 0.78, green: 0.60, blue: 0.32, alpha: 1))
        default: // forest
            return Theme(surface: "tile_surface", fill: "tile_fill",
                skyTop: UIColor(red: 0.40, green: 0.72, blue: 0.95, alpha: 1),
                skyBottom: UIColor(red: 0.75, green: 0.89, blue: 0.99, alpha: 1),
                hillFar: UIColor(red: 0.62, green: 0.80, blue: 0.70, alpha: 1),
                hillNear: UIColor(red: 0.40, green: 0.66, blue: 0.46, alpha: 1))
        }
    }
}
