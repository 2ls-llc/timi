import Foundation

/// All sprite row-art, verbatim from the cat prototype (mochi-timer.jsx 62–111).
public enum Sprites {
    public static let HEART = [".#.#.", "#####", ".###.", "..#.."]
    public static let MINI_HEART = ["#.#", "###", ".#."]
    /// multiplication sign for the ♥×n tally (3×3 so it reads ×, not a letter X)
    public static let CROSS = ["#.#", ".#.", "#.#"]
    /// tally heart — 5 rows so it spans the 3×5 font's cap line to baseline and
    /// sits level with the count (the prototype's 4-row HEART hung a pixel low)
    public static let TALLY_HEART = [".#.#.", "#####", "#####", ".###.", "..#.."]
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
