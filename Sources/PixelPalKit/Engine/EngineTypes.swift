import Foundation

// Shared math helpers, mirroring the prototype's `clamp`/`lerp`/`TAU`.

public let TAU = Double.pi * 2

@inlinable public func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double {
    min(b, max(a, v))
}

@inlinable public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

/// `fmt(ms)` from the prototype: ceil to seconds, "m:ss".
public func formatMillis(_ ms: Double) -> String {
    let t = Int(max(0, (ms / 1000).rounded(.up)))
    return "\(t / 60):" + String(format: "%02d", t % 60)
}

public struct Vec2: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
    public static let zero = Vec2(0, 0)
}

/// Axis-aligned rect used for physics bounds (a screen's visibleFrame).
/// Y-up, like AppKit global coordinates.
public struct Rect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var midX: Double { x + w / 2 }
    public var midY: Double { y + h / 2 }
}

/// Deterministic RNG so tests can pin every `Math.random()` site.
public struct SplitMix64: Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// Uniform in [0, 1), like `Math.random()`.
    public mutating func next() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9007199254740992.0)
    }
}

/// 8-bit RGBA color. The canvas buffer stores non-premultiplied RGBA8.
public struct RGBA: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    /// 0xRRGGBB hex, fully opaque.
    public init(hex: UInt32) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = 255
    }
    public static let white = RGBA(hex: 0xFFFFFF)
}
