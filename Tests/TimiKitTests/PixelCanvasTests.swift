import XCTest
@testable import TimiKit

final class PixelCanvasTests: XCTestCase {
    private let red = RGBA(hex: 0xFF0000)
    private let clear = RGBA(r: 0, g: 0, b: 0, a: 0)

    func testPxClipsAtEveryEdge() {
        var c = PixelCanvas()
        c.px(-2, -2, red, 4, 4)   // overlaps the top-left corner by 2×2
        XCTAssertEqual(c.pixel(0, 0), red)
        XCTAssertEqual(c.pixel(1, 1), red)
        XCTAssertEqual(c.pixel(2, 2), clear)
        c.px(55, 47, red, 10, 10) // bottom-right corner, mostly off-canvas
        XCTAssertEqual(c.pixel(55, 47), red)
        c.px(200, 200, red)       // fully outside: no crash, no change
        c.px(-50, 10, red, 20, 1) // fully outside on the left
        XCTAssertEqual(c.pixel(0, 10), clear)
    }

    func testSpriteAndLean() {
        var c = PixelCanvas()
        c.sprite(["#.#", ".#."], 10, 10, red)
        XCTAssertEqual(c.pixel(10, 10), red)
        XCTAssertEqual(c.pixel(11, 10), clear)
        XCTAssertEqual(c.pixel(12, 10), red)
        XCTAssertEqual(c.pixel(11, 11), red)

        var lean = PixelCanvas()
        lean.spriteLean(["#", "#"], 20, 20, red, 1)  // top half shifts by +1
        XCTAssertEqual(lean.pixel(21, 20), red)
        XCTAssertEqual(lean.pixel(20, 20), clear)
        XCTAssertEqual(lean.pixel(20, 21), red)
    }

    func testFontWidthAndColonBlink() {
        XCTAssertEqual(Font3x5.width("25:00"), 17)
        XCTAssertEqual(Font3x5.width("NYA!"), 13)
        var on = PixelCanvas(), off = PixelCanvas()
        on.text("1:1", 0, 0, red, colonOn: true)
        off.text("1:1", 0, 0, red, colonOn: false)
        // The colon column sits at x = 4 (glyph "1" is 3 wide + 1 gap).
        XCTAssertEqual(on.pixel(4, 1), red)
        XCTAssertEqual(off.pixel(4, 1), clear)
        // Digits after the colon land in the same place either way.
        XCTAssertEqual(on.pixel(7, 0), off.pixel(7, 0))
    }

    func testFlashOverlayBlendsOverOpaqueAndTransparent() {
        var c = PixelCanvas()
        c.px(5, 5, red)
        c.flashOverlay(.white, alpha: 0.5)
        let blended = c.pixel(5, 5)
        XCTAssertEqual(blended.r, 255)
        XCTAssertEqual(Int(blended.g), 127, accuracy: 1)
        XCTAssertEqual(blended.a, 255)
        let ghost = c.pixel(0, 0)  // was transparent: a half-alpha white veil
        XCTAssertEqual(ghost.r, 255)
        XCTAssertEqual(Int(ghost.a), 127, accuracy: 1)
    }

    func testOutlineRingsOpaquePixels() {
        var c = PixelCanvas()
        c.px(10, 10, red)
        let ink = RGBA(hex: 0x120E08)
        c.outline(ink)
        XCTAssertEqual(c.pixel(10, 10), red, "the pixel itself is untouched")
        for (dx, dy) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)] {
            XCTAssertEqual(c.pixel(10 + dx, 10 + dy), ink, "8-neighbor (\(dx),\(dy)) outlined")
        }
        XCTAssertEqual(c.pixel(10, 8), clear, "two away stays clear")
        XCTAssertEqual(c.pixel(12, 12), clear)
    }

    func testOutlineAtCanvasEdgeDoesNotCrash() {
        var c = PixelCanvas()
        c.px(0, 0, red)
        c.px(55, 47, red)
        c.outline(RGBA(hex: 0x000000))
        XCTAssertEqual(c.pixel(1, 1), RGBA(hex: 0x000000))
        XCTAssertEqual(c.pixel(54, 46), RGBA(hex: 0x000000))
    }

    func testClear() {
        var c = PixelCanvas()
        c.px(3, 3, red, 10, 10)
        c.clear()
        XCTAssertEqual(c.pixel(5, 5), clear)
    }
}
