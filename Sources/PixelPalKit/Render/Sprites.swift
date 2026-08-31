import Foundation

/// All sprite row-art, verbatim from the prototype files.
public enum Sprites {
    // Shared
    public static let HEART = [".#.#.", "#####", ".###.", "..#.."]
    public static let MINI_HEART = ["#.#", "###", ".#."]
    public static let ZGLYPH = ["###", ".#.", "###"]
    public static let FEET_A = "..##.....##.."
    public static let FEET_B = "...##...##..."
    public static let DANGLE_A = "....#...#...."
    public static let DANGLE_B = "...#.....#..."

    // Pip (pip-timer-v4-3.jsx 55–75)
    public static let PIP_BODY = [
        "...#######...",
        "..#########..",
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let PIP_BODY_SQ = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let PIP_FEET_SIT = "#############"

    // Mochi body variants (mochi-timer.jsx 62–104)
    public static let MOCHI_STAND = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let MOCHI_TALL = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let MOCHI_LOAF = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
    ]
    public static let MOCHI_CURL = [
        "..#########..",
        ".###########.",
        "#############",
        "#############",
        "#############",
        ".###########.",
        "..#########..",
    ]
    public static let MOCHI_SQUASH = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
}
