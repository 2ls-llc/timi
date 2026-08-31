import XCTest
@testable import PixelPalKit

final class SynthDSPTests: XCTestCase {
    private let sr = 48_000.0

    private func render(_ sounds: [PalSound], seconds: Double) -> [Float] {
        let dsp = SynthDSP(sampleRate: sr)
        for s in sounds { dsp.schedule(s) }
        let frames = Int(seconds * sr)
        var out = [Float](repeating: 0, count: frames)
        out.withUnsafeMutableBufferPointer { buf in
            dsp.render(into: buf.baseAddress!, frames: frames)
        }
        return out
    }

    private func rms(_ samples: ArraySlice<Float>) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        return (sum / Double(samples.count)).squareRoot()
    }

    func testSilentTickRendersNothing() {
        let out = render([.tick(volume: 0.005, pitch: 1)], seconds: 0.1)
        XCTAssertEqual(rms(out[...]), 0, "vol ≤ 0.01 skips the tick entirely")
    }

    func testTickRendersShortBlip() {
        let out = render([.tick(volume: 1, pitch: 1)], seconds: 0.1)
        let during = rms(out[0..<Int(0.018 * sr)])
        let after = rms(out[Int(0.05 * sr)...])
        XCTAssertGreaterThan(during, 0.001)
        XCTAssertLessThan(after, 1e-4, "18 ms voice is gone by 50 ms")
    }

    func testBlipFrequencyViaZeroCrossings() {
        let out = render([.blip], seconds: 0.03)
        // Count sign changes over the first 25 ms of the 880 Hz square.
        let n = Int(0.025 * sr)
        var crossings = 0
        for i in 1..<n where (out[i] >= 0) != (out[i - 1] >= 0) { crossings += 1 }
        let freq = Double(crossings) / 2 / 0.025
        XCTAssertEqual(freq, 880, accuracy: 60)
    }

    func testEnvelopeHoldsThenReleases() {
        // sq(880, 0.1, 0.04): attack 4 ms, hold to 60 ms, release to 100 ms.
        let dsp = SynthDSP(sampleRate: sr)
        dsp.scheduleVoice(.sq(880, 0.1, 0.04))
        var out = [Float](repeating: 0, count: Int(0.12 * sr))
        out.withUnsafeMutableBufferPointer { dsp.render(into: $0.baseAddress!, frames: $0.count) }
        let hold = rms(out[Int(0.02 * sr)..<Int(0.05 * sr)])
        let release = rms(out[Int(0.085 * sr)..<Int(0.098 * sr)])
        let after = rms(out[Int(0.115 * sr)...])
        XCTAssertGreaterThan(hold, release * 1.5)
        XCTAssertLessThan(after, 1e-4)
    }

    func testFanfareVoiceCounts() {
        XCTAssertEqual(SoundRecipes.voices(for: .fanfare(volume: 1, pipTopNote: true)).count, 12)
        XCTAssertEqual(SoundRecipes.voices(for: .fanfare(volume: 1, pipTopNote: false)).count, 11)
    }

    func testQuietFanfareIsHalfVolume() {
        let loud = render([.fanfare(volume: 1, pipTopNote: true)], seconds: 0.3)
        let quiet = render([.fanfare(volume: 0.5, pipTopNote: true)], seconds: 0.3)
        let ratio = rms(quiet[...]) / rms(loud[...])
        XCTAssertEqual(ratio, 0.5, accuracy: 0.08)
    }

    func testPurrAmplitudeModulatesAt23Hz() {
        let out = render([.purr], seconds: 1.0)
        // Envelope with a one-carrier-period window (1/52 s) so the 52 Hz triangle
        // ripple cancels, hopped every 2 ms; then count mean crossings — a 23 Hz
        // modulator crosses its mean 46 times per second.
        let win = Int(sr / 52)
        let hop = Int(0.002 * sr)
        var env: [Double] = []
        var i = Int(0.1 * sr)
        while i + win < Int(0.9 * sr) {
            env.append(rms(out[i..<(i + win)]))
            i += hop
        }
        let mean = env.reduce(0, +) / Double(env.count)
        var crossings = 0
        for j in 1..<env.count where (env[j] >= mean) != (env[j - 1] >= mean) {
            crossings += 1
        }
        let rate = Double(crossings) / 2 / 0.8
        XCTAssertEqual(rate, 23, accuracy: 4)
        // Depth: gain swings 0.022 ± 0.02 — the envelope must visibly throb.
        XCTAssertGreaterThan(env.max()! / max(env.min()!, 1e-6), 3)
    }

    func testPurrLastsAboutOnePointFourFiveSeconds() {
        let out = render([.purr], seconds: 1.6)
        XCTAssertGreaterThan(rms(out[Int(1.2 * sr)..<Int(1.35 * sr)]), 1e-5)
        XCTAssertLessThan(rms(out[Int(1.5 * sr)...]), 1e-5)
    }

    func testHissIsNoiseWithFastDecay() {
        let out = render([.hiss(1)], seconds: 0.25)
        let early = rms(out[0..<Int(0.02 * sr)])
        let late = rms(out[Int(0.14 * sr)..<Int(0.16 * sr)])
        XCTAssertGreaterThan(early, 0.002)
        XCTAssertLessThan(late, early * 0.1, "exponential decay to silence over 160 ms")
    }

    func testMuteViaMasterGain() {
        let dsp = SynthDSP(sampleRate: sr)
        dsp.masterGain = 0
        dsp.schedule(.blip)
        var out = [Float](repeating: 0, count: Int(0.05 * sr))
        out.withUnsafeMutableBufferPointer { dsp.render(into: $0.baseAddress!, frames: $0.count) }
        XCTAssertEqual(rms(out[...]), 0)
    }

    func testDelayedSecondNote() {
        // bleep2: second note starts at +75 ms.
        let out = render([.bleep2(659.25, 987.77)], seconds: 0.2)
        let gap = rms(out[Int(0.065 * sr)..<Int(0.074 * sr)])
        let second = rms(out[Int(0.08 * sr)..<Int(0.13 * sr)])
        XCTAssertGreaterThan(second, gap * 2)
    }

    func testVoicesExpire() {
        let dsp = SynthDSP(sampleRate: sr)
        dsp.schedule(.blip)
        XCTAssertEqual(dsp.activeVoiceCount, 1)
        var out = [Float](repeating: 0, count: Int(0.2 * sr))
        out.withUnsafeMutableBufferPointer { dsp.render(into: $0.baseAddress!, frames: $0.count) }
        XCTAssertEqual(dsp.activeVoiceCount, 0, "expired voices are removed")
    }
}
