import Foundation

/// Draws one frame of the 56×48 canvas from the engine's state. Pure read —
/// all state mutation happens in `PalEngine.step`. Transcribed from the cat
/// prototype's draw section verbatim.
public enum Renderer {
    public static func draw(into canvas: inout PixelCanvas, engine e: PalEngine) {
        let f = e.flags
        let t = f.tMs
        let pal = e.config.palette

        canvas.clear()

        // hearts tally — ♥×n, top-left, sharing the clock line (arcade HUD:
        // score left, time right). The prototype drew one sprite per heart, but
        // hearts persist per day natively, so a row would crowd the 56 px canvas
        // and silently cap at 8; the counter stays 13–17 px and counts to 99.
        if e.hearts > 0 {
            let popping = t - e.heartPopT < 130
            // heart and digits share rows 2–6; the × is centered on row 4
            canvas.sprite(Sprites.TALLY_HEART, 2, 2, popping ? pal.segPop : pal.pink)
            canvas.sprite(Sprites.CROSS, 8, 3, pal.pink)
            canvas.text("\(min(e.hearts, 99))", 12, 2, pal.pink)
        }
        // flying heart
        if let fp = f.flyHeartPos {
            canvas.sprite(Sprites.MINI_HEART, jsRound(fp.x) - 1, jsRound(fp.y) - 1, pal.pink)
        }
        // pat hearts
        for h in e.miniHearts {
            canvas.sprite(Sprites.MINI_HEART, jsRound(h.x) - 1, jsRound(h.y) - 1, pal.pink)
        }

        // clock
        if f.labelVisible {
            let s = formatMillis(e.mode == .idle ? e.durationMs : e.remainingMs)
            let colonOn = !f.running || Int(floor(t / 500)) % 2 == 0
            let color = f.panic ? (Int(floor(t / 250)) % 2 == 1 ? pal.red : pal.txt) : pal.txt
            // right-aligned (2 px margin, mirroring the tally's left margin);
            // even ♥×99 vs the longest clock (90:00) leaves 18 px of air
            canvas.text(s, 54 - Font3x5.width(s), 2, color, colonOn: colonOn)
        }
        // done banner
        if e.mode == .done && t - e.doneT < 2200 {
            let banner = e.config.banner
            let color = Int(floor(t / 180)) % 2 == 1 ? pal.amber : RGBA.white
            canvas.text(banner, jsRound(28 - Double(Font3x5.width(banner)) / 2), 2, color)
        }

        // progress bar
        var barC = pal.primary
        if f.running && e.remainingMs / 1000 <= 60 { barC = pal.amber }
        if f.panic { barC = Int(floor(t / 250)) % 2 == 1 ? pal.red : pal.amber }
        for i in 0..<20 {
            let popping = i == e.segPopI && t - e.segPopT < 130
            let c = popping ? pal.segPop : (i < f.segs ? barC : pal.slot)
            canvas.px(8 + i * 2, 41, c, 1, 3)
        }

        // the cat
        drawTimi(into: &canvas, engine: e)

        // High-contrast outline around everything drawn so far (creature, tail,
        // clock, hearts, bar). Particles stay outline-free — they're ephemeral
        // sparkle and read fine as bare pixels.
        if e.outlineEnabled {
            canvas.outline(RGBA(r: 0x12, g: 0x0E, b: 0x08, a: 210))
        }

        // particles above the cat
        for z in e.zs {
            canvas.sprite(Sprites.ZGLYPH, jsRound(z.x), jsRound(z.y), pal.cyan)
        }
        for c in e.conf {
            canvas.px(jsRound(c.x), jsRound(c.y), c.c)
        }

        // milestone flash
        if t - e.flashT < 90 {
            canvas.flashOverlay(pal.primary, alpha: pal.flashAlpha)
        }
    }

    // MARK: - Timi

    private static func drawTimi(into canvas: inout PixelCanvas, engine e: PalEngine) {
        let f = e.flags
        let t = f.tMs
        let pal = e.config.palette
        let cream = pal.primary, dim = pal.dim, eye = pal.eye, pink = pal.pink

        let bx = 21 + f.wig
        let body: [String]
        let faceRow: Int
        let by: Int
        if f.sleepingNow {
            body = Sprites.CURL; faceRow = 3; by = 22
        } else if f.loaf {
            body = Sprites.LOAF; faceRow = 2; by = 22
        } else if f.stretching {
            body = Sprites.TALL; faceRow = 4; by = 19 + f.bounce + f.lift
        } else if f.squashing || f.crouch {
            body = Sprites.SQUASH; faceRow = 2; by = 23 + f.bounce + f.lift
        } else {
            body = Sprites.STAND; faceRow = 3; by = 21 + f.bounce + f.lift
        }
        let bodyH = body.count

        // ground shadow
        if !f.airborne {
            let h = min(4, abs(f.lift) + max(0, -f.bounce))
            let w = 9 - h
            canvas.px(28 - Int(floor(Double(w) / 2)), 31, pal.shadow, w, 1)
        }

        // tail (behind the body)
        if !f.sleepingNow {
            var txp = Double(bx) + 12.5
            var typ = Double(by + min(5, bodyH - 2))
            let puff = f.panic && !f.reduceMotion
            for i in 0..<4 {
                txp += cos(e.tail[i]) * 2.3
                typ += sin(e.tail[i]) * 2.3
                let cx2 = jsRound(txp), cy2 = jsRound(typ)
                canvas.px(cx2, cy2, i == 3 ? Palette.tailTip : cream)
                if puff {
                    canvas.px(cx2 + 1, cy2, dim)
                    canvas.px(cx2, cy2 + 1, dim)
                }
            }
        } else {
            // curled tail across the front
            canvas.px(bx + 2, by + bodyH - 2, dim, 8, 1)
        }

        // body
        if f.lean != 0 {
            canvas.spriteLean(body, bx, by, cream, f.lean)
        } else {
            canvas.sprite(body, bx, by, cream)
        }
        canvas.px(bx + 1, by + bodyH - 1, dim, 11, 1)

        // ears
        let earsFlat = f.panic || t < e.sadUntil || (f.airborne && f.speed > Physics.worriedSpeed)
        if !f.sleepingNow {
            if earsFlat {
                canvas.px(bx, by + 1, cream, 2, 1)
                canvas.px(bx + 11, by + 1, cream, 2, 1)
            } else {
                let perk = f.noticing ? 1 : 0
                canvas.px(bx + 1, by - 1 - perk, cream); canvas.px(bx + 1, by - 2 - perk, cream)
                canvas.px(bx + 2, by - 1 - perk, cream)
                canvas.px(bx + 11, by - 1 - perk, cream); canvas.px(bx + 11, by - 2 - perk, cream)
                canvas.px(bx + 10, by - 1 - perk, cream)
                canvas.px(bx + 1, by - 1 - perk, pink); canvas.px(bx + 11, by - 1 - perk, pink)
            }
        } else {
            canvas.px(bx + 2, by - 1, cream); canvas.px(bx + 10, by - 1, cream)
        }

        // feet
        if !f.sleepingNow && !f.loaf && !f.squashing && !f.crouch {
            let feet: String
            if f.airborne {
                feet = Int(floor(t / 260)) % 2 == 1 ? Sprites.DANGLE_A : Sprites.DANGLE_B
            } else if f.happy && !f.walking && e.mode == .idle {
                // kneading
                feet = Int(floor(t / 300)) % 2 == 1 ? Sprites.FEET_A : Sprites.FEET_B
            } else {
                feet = f.walking ? (Int(floor(t / 130)) % 2 == 1 ? Sprites.FEET_A : Sprites.FEET_B) : Sprites.FEET_A
            }
            canvas.sprite([feet], bx, by + bodyH, cream)
        }

        // landing dust
        if f.landing && !f.reduceMotion {
            canvas.px(bx - 1, by + bodyH, dim)
            canvas.px(bx + 13, by + bodyH, dim)
        }

        // face
        let er = by + faceRow
        let eox = f.eox, eoy = f.eoy
        let patAge = t - e.patT
        // whiskers
        if !f.sleepingNow {
            canvas.px(bx - 2, er + 1, dim, 2, 1)
            canvas.px(bx + 13, er + 1, dim, 2, 1)
        }
        // nose + mouth
        if !f.sleepingNow {
            canvas.px(bx + 6, er + 2, pink)
            if !f.panic && !f.worried {
                canvas.px(bx + 5, er + 3, eye)
                canvas.px(bx + 7, er + 3, eye)
            }
        }
        if e.mode == .done && t - e.doneT < 3200 {
            canvas.px(bx + 3, er, eye); canvas.px(bx + 2, er + 1, eye); canvas.px(bx + 4, er + 1, eye)
            canvas.px(bx + 9, er, eye); canvas.px(bx + 8, er + 1, eye); canvas.px(bx + 10, er + 1, eye)
            canvas.px(bx + 1, er + 2, pink); canvas.px(bx + 11, er + 2, pink)
        } else if patAge < 1300 {
            // cat slow-blink: half, closed, half
            if patAge < 250 || patAge > 800 {
                canvas.px(bx + 3, er + 1, eye)
                canvas.px(bx + 9, er + 1, eye)
            } else {
                canvas.px(bx + 3, er + 1, eye, 2, 1)
                canvas.px(bx + 8, er + 1, eye, 2, 1)
            }
            canvas.px(bx + 1, er + 2, pink); canvas.px(bx + 11, er + 2, pink)
        } else if t < e.sadUntil {
            canvas.px(bx + 3, er + 1, eye, 2, 1)
            canvas.px(bx + 8, er + 1, eye, 2, 1)
            canvas.px(bx + 5, er + 3, eye); canvas.px(bx + 7, er + 3, eye)
            canvas.px(bx + 6, er + 4, eye)
        } else if f.sleepingNow || e.mode == .paused || f.stretching {
            canvas.px(bx + 3, er + 1, eye, 2, 1)
            canvas.px(bx + 8, er + 1, eye, 2, 1)
        } else if f.blinking {
            if e.winking {
                canvas.px(bx + 3, er + 1, eye, 2, 1)
                canvas.px(bx + 9 + eox, er + eoy, eye, 1, 2)
            } else {
                canvas.px(bx + 3, er + 1, eye, 2, 1)
                canvas.px(bx + 8, er + 1, eye, 2, 1)
            }
        } else if f.panic || f.worried {
            canvas.px(bx + 2 + eox, er, eye, 2, 2)
            canvas.px(bx + 8 + eox, er, eye, 2, 2)
        } else if f.happy {
            canvas.px(bx + 3, er + 1, eye, 2, 1)
            canvas.px(bx + 8, er + 1, eye, 2, 1)
            canvas.px(bx + 1, er + 2, pink); canvas.px(bx + 11, er + 2, pink)
        } else if f.noticing {
            canvas.px(bx + 2 + eox, er, eye, 2, 2)
            canvas.px(bx + 8 + eox, er, eye, 2, 2)
        } else {
            canvas.px(bx + 3 + eox, er + eoy, eye, 1, 2)
            canvas.px(bx + 9 + eox, er + eoy, eye, 1, 2)
        }

        // wake "!"
        if t - e.wakeFlash < 450 {
            canvas.px(bx + 6, by - 8, pal.amber, 1, 3)
            canvas.px(bx + 6, by - 4, pal.amber)
        }
    }
}
