import Foundation

/// All sprite row-art, verbatim from the cat prototype (mochi-timer.jsx 62–111).
public enum Sprites {
    public static let HEART = [".#.#.", "#####", ".###.", "..#.."]
    public static let MINI_HEART = ["#.#", "###", ".#."]
    public static let ZGLYPH = ["###", ".#.", "###"]
    public static let FEET_A = "..##.....##.."
    public static let FEET_B = "...##...##..."
    public static let DANGLE_A = "....#...#...."
    public static let DANGLE_B = "...#.....#..."

    // Body variants (13 wide)
    public static let STAND = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let TALL = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
    public static let LOAF = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        "#############",
        "#############",
    ]
    public static let CURL = [
        "..#########..",
        ".###########.",
        "#############",
        "#############",
        "#############",
        ".###########.",
        "..#########..",
    ]
    public static let SQUASH = [
        ".###########.",
        "#############",
        "#############",
        "#############",
        ".###########.",
    ]
}
