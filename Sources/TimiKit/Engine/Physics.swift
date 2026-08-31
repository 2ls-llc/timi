import Foundation

/// JS `Math.round` semantics: floor(x + 0.5). Differs from Swift's `.rounded()`
/// only at exact negative halves, but the prototype is the source of truth.
@inlinable public func jsRound(_ x: Double) -> Int {
    Int((x + 0.5).rounded(.down))
}

/// Pure physics steps with the prototype's constants. Position space is global
/// AppKit screen coordinates (y up); hop space is canvas pixels (y down).
public enum Physics {
    public static let homeStiffness = 90.0
    public static let homeDamping = 11.0
    public static let dragStiffness = 380.0
    public static let dragDamping = 26.0
    public static let zoomiesStiffness = 200.0
    public static let zoomiesDamping = 16.0
    public static let scaleStiffness = 240.0
    public static let scaleDamping = 13.0
    public static let flightDrag = 1.5
    public static let bounceHalfSize = 78.0
    public static let restitution = 0.72
    public static let throwSpeed = 650.0
    public static let throwSpeedCap = 2600.0
    public static let flightExitSpeed = 140.0
    public static let homeMargin = 90.0
    public static let hopGravity = 260.0
    public static let walkSpeed = 90.0
    public static let worriedSpeed = 420.0

    /// Damped spring toward a target: accelerate, exponential damping, integrate.
    public static func springStep(pos: inout Vec2, vel: inout Vec2, target: Vec2,
                                  stiffness: Double, damping: Double, dt: Double) {
        vel.x += (target.x - pos.x) * stiffness * dt
        vel.y += (target.y - pos.y) * stiffness * dt
        let dk = exp(-damping * dt)
        vel.x *= dk
        vel.y *= dk
        pos.x += vel.x * dt
        pos.y += vel.y * dt
    }

    /// Free flight with wall bounces inside `bounds` (a screen's visibleFrame).
    /// Returns the impact strength (0.2–1) if a wall was hit this step.
    public static func flightStep(pos: inout Vec2, vel: inout Vec2, bounds: Rect,
                                  dt: Double) -> Double? {
        let drg = exp(-flightDrag * dt)
        vel.x *= drg
        vel.y *= drg
        pos.x += vel.x * dt
        pos.y += vel.y * dt
        let r = bounceHalfSize
        var hit = false
        if pos.x < bounds.minX + r {
            pos.x = bounds.minX + r; vel.x = abs(vel.x) * restitution; hit = true
        } else if pos.x > bounds.maxX - r {
            pos.x = bounds.maxX - r; vel.x = -abs(vel.x) * restitution; hit = true
        }
        if pos.y < bounds.minY + r {
            pos.y = bounds.minY + r; vel.y = abs(vel.y) * restitution; hit = true
        } else if pos.y > bounds.maxY - r {
            pos.y = bounds.maxY - r; vel.y = -abs(vel.y) * restitution; hit = true
        }
        guard hit else { return nil }
        return clamp(hypot(vel.x, vel.y) / 1400, 0.2, 1)
    }

    /// Hop in canvas pixels, y down, ground at 0. Returns true on a hard landing
    /// (previous hopY < −0.6 crossing the ground) — squash frame + dust + thud.
    public static func hopStep(hopY: inout Double, hopV: inout Double, dt: Double) -> Bool {
        let prev = hopY
        hopV += hopGravity * dt
        hopY += hopV * dt
        if hopY >= 0 {
            hopY = 0
            hopV = 0
            return prev < -0.6
        }
        return false
    }

    /// Where the pal settles after a drag/flight: 90 pt inside the screen.
    public static func clampHome(_ p: Vec2, in bounds: Rect) -> Vec2 {
        Vec2(clamp(p.x, bounds.minX + homeMargin, bounds.maxX - homeMargin),
             clamp(p.y, bounds.minY + homeMargin, bounds.maxY - homeMargin))
    }

    /// Axis-aligned velocity squash: dominant axis stretches 1+st, the other 1−0.6·st.
    public static func squash(vel: Vec2, reduceMotion: Bool) -> (sx: Double, sy: Double) {
        let speed = hypot(vel.x, vel.y)
        let st = clamp(speed * 0.0004, 0, 0.16) * (reduceMotion ? 0.3 : 1)
        if abs(vel.x) > abs(vel.y) {
            return (1 + st, 1 - st * 0.6)
        } else {
            return (1 - st * 0.6, 1 + st)
        }
    }
}
