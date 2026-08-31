import Foundation

/// Pure chiptune DSP: voice descriptions (transcribed from the prototypes'
/// WebAudio recipes), sample rendering, and the master chain
/// (gain 0.5 → low-pass 7.5 kHz). No audio framework — the app hosts this
/// inside an AVAudioSourceNode; tests render buffers directly.

public enum Wave: Sendable {
    case square, triangle, sine, noise
}

public struct EnvPoint: Sendable {
    public var t: Double
    public var gain: Double
    /// Interpolation *into* this point: false = linear (WebAudio linearRamp),
    /// true = exponential (WebAudio exponentialRamp).
    public var exponential: Bool
    public init(_ t: Double, _ gain: Double, exponential: Bool = false) {
        self.t = t; self.gain = gain; self.exponential = exponential
    }
}

/// One scheduled oscillator/noise voice.
public struct SynthVoice: Sendable {
    public var wave: Wave
    public var freq: Double
    /// Exponential frequency ramp target over `freqRampDur` (WebAudio
    /// exponentialRampToValueAtTime), nil for constant pitch.
    public var freqEnd: Double?
    public var freqRampDur: Double
    /// Vibrato LFO: rate fixed at 9 Hz in the prototype, depth in Hz.
    public var vibratoDepth: Double
    public var vibratoRate: Double
    /// Amplitude modulation (purr): gain += amDepth·sin(2π·amRate·t).
    public var amRate: Double
    public var amDepth: Double
    /// One-pole high-pass cutoff (hiss), nil for none.
    public var highpass: Double?
    public var envelope: [EnvPoint]
    /// Start delay in seconds from schedule time.
    public var delay: Double

    public var duration: Double { envelope.last?.t ?? 0 }

    /// The prototype's `sq(freq, dur, vol, when, type)`: 4 ms linear attack,
    /// hold to 60% of duration, linear release.
    public static func sq(_ freq: Double, _ dur: Double, _ vol: Double,
                          _ delay: Double = 0, _ wave: Wave = .square) -> SynthVoice {
        SynthVoice(wave: wave, freq: freq, freqEnd: nil, freqRampDur: dur,
                   vibratoDepth: 0, vibratoRate: 9, amRate: 0, amDepth: 0,
                   highpass: nil,
                   envelope: [EnvPoint(0, 0.0001), EnvPoint(0.004, vol),
                              EnvPoint(dur * 0.6, vol), EnvPoint(dur, 0.0001)],
                   delay: delay)
    }

    /// The prototype's `sweep` (boing): square, exponential freq ramp, no hold.
    public static func sweep(_ f0: Double, _ f1: Double, _ dur: Double,
                             _ vol: Double) -> SynthVoice {
        SynthVoice(wave: .square, freq: f0, freqEnd: f1, freqRampDur: dur,
                   vibratoDepth: 0, vibratoRate: 9, amRate: 0, amDepth: 0,
                   highpass: nil,
                   envelope: [EnvPoint(0, 0.0001), EnvPoint(0.004, vol),
                              EnvPoint(dur, 0.0001)],
                   delay: 0)
    }

    /// Mochi's `bend`: 12 ms attack, exponential freq ramp, optional vibrato.
    public static func bend(_ f0: Double, _ f1: Double, _ dur: Double, _ vol: Double,
                            _ wave: Wave = .square, vibrato: Double = 0) -> SynthVoice {
        SynthVoice(wave: wave, freq: f0, freqEnd: f1, freqRampDur: dur,
                   vibratoDepth: vibrato, vibratoRate: 9, amRate: 0, amDepth: 0,
                   highpass: nil,
                   envelope: [EnvPoint(0, 0.0001), EnvPoint(0.012, vol),
                              EnvPoint(dur, 0.0001)],
                   delay: 0)
    }
}

/// PalSound → voices, exactly per the two prototypes' `makeAudio()`.
public enum SoundRecipes {
    public static func voices(for sound: PalSound) -> [SynthVoice] {
        switch sound {
        case .tick(let volume, let pitch):
            guard volume > 0.01 else { return [] }
            return [.sq(1250 * pitch, 0.018, 0.028 * volume)]

        case .bleep2(let a, let b):
            return [.sq(a, 0.06, 0.05), .sq(b, 0.06, 0.05, 0.075)]

        case .buzz:
            return [.sq(196, 0.12, 0.05), .sq(98, 0.12, 0.03, 0.005, .triangle)]

        case .fanfare(let volume, let pipTopNote):
            var voices: [SynthVoice] = []
            for (i, f) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
                voices.append(.sq(f, 0.07, 0.05 * volume, Double(i) * 0.08))
                voices.append(.sq(f / 2, 0.07, 0.025 * volume, Double(i) * 0.08, .triangle))
            }
            for f in [523.25, 659.25, 783.99] {
                voices.append(.sq(f, 0.28, 0.035 * volume, 0.36))
            }
            if pipTopNote {
                voices.append(.sq(1567.98, 0.28, 0.02 * volume, 0.36))
            }
            return voices

        case .boing(let i, let bendStyle):
            if bendStyle {
                // Mochi: bend-based boing (12 ms attack).
                return [.bend(420 + 200 * i, 150, 0.09, 0.05 * i + 0.015)]
            }
            return [.sweep(420 + 200 * i, 150, 0.09, 0.05 * i + 0.015)]

        case .thud:
            return [.sq(180, 0.035, 0.022, 0, .triangle)]

        case .blip:
            return [.sq(880, 0.03, 0.04)]

        case .sleepy:
            return [.sq(392, 0.09, 0.03, 0, .triangle),
                    .sq(261.63, 0.12, 0.03, 0.11, .triangle)]

        case .wake:
            return [.sq(1046.5, 0.04, 0.04)]

        case .pat:
            return [.sq(523.25, 0.06, 0.04, 0, .triangle),
                    .sq(659.25, 0.09, 0.04, 0.07, .triangle)]

        case .meow:
            return [.bend(760, 480, 0.22, 0.05, .square, vibrato: 14)]

        case .mew:
            return [.bend(880, 1150, 0.14, 0.045, .square, vibrato: 8)]

        case .trill:
            return [.sq(880, 0.035, 0.045), .sq(1046, 0.035, 0.045, 0.045),
                    .sq(880, 0.035, 0.045, 0.09), .sq(1174, 0.05, 0.045, 0.14)]

        case .mrrp:
            return [.bend(320, 250, 0.18, 0.04, .triangle, vibrato: 4)]

        case .purr:
            // The oscillator + LFO run until t0+1.45 in the prototype — the 23 Hz
            // throb audibly outlives the 1.0→1.4 s gain fade (see render(): the AM
            // sum may push net gain negative, a WebAudio polarity flip).
            return [SynthVoice(
                wave: .triangle, freq: 52, freqEnd: nil, freqRampDur: 1.45,
                vibratoDepth: 0, vibratoRate: 9, amRate: 23, amDepth: 0.02,
                highpass: nil,
                envelope: [EnvPoint(0, 0.022), EnvPoint(1.0, 0.022),
                           EnvPoint(1.4, 0.0001), EnvPoint(1.45, 0.0001)],
                delay: 0)]

        case .hiss(let i):
            return [SynthVoice(
                wave: .noise, freq: 0, freqEnd: nil, freqRampDur: 0.16,
                vibratoDepth: 0, vibratoRate: 9, amRate: 0, amDepth: 0,
                highpass: 2600,
                envelope: [EnvPoint(0, 0.05 * i), EnvPoint(0.16, 0.0001, exponential: true)],
                delay: 0)]
        }
    }
}

/// Additive renderer with the master chain. Not thread-safe by itself — the
/// host serializes access (the audio render thread drains a pending queue).
public final class SynthDSP {
    public let sampleRate: Double
    /// Master gain: 0.5 (prototype) × user volume × mute.
    public var masterGain: Double = 0.5

    private struct Active {
        var voice: SynthVoice
        var startSample: Int64
        var phase: Double = 0
        var vibPhase: Double = 0
        var amPhase: Double = 0
        // Per-voice biquad high-pass state + coefficients (hiss). WebAudio's
        // BiquadFilterNode is 2nd order (12 dB/oct), Q defaults to 1.
        var hpB0 = 0.0, hpB1 = 0.0, hpB2 = 0.0, hpA1 = 0.0, hpA2 = 0.0
        var hpX1 = 0.0, hpX2 = 0.0, hpY1 = 0.0, hpY2 = 0.0
        var rng: UInt64 = 0x9E3779B97F4A7C15

        mutating func configureHighpass(cutoff: Double, sampleRate: Double) {
            let omega = 2 * Double.pi * cutoff / sampleRate
            let alpha = sin(omega) / 2  // Q = 1
            let cosw = cos(omega)
            let a0 = 1 + alpha
            hpB0 = ((1 + cosw) / 2) / a0
            hpB1 = (-(1 + cosw)) / a0
            hpB2 = ((1 + cosw) / 2) / a0
            hpA1 = (-2 * cosw) / a0
            hpA2 = (1 - alpha) / a0
        }
    }

    private var active: [Active] = []
    private var sampleTime: Int64 = 0
    // Master low-pass biquad (RBJ, 7.5 kHz, Q = 1 like WebAudio's default).
    private var lpB0 = 0.0, lpB1 = 0.0, lpB2 = 0.0, lpA1 = 0.0, lpA2 = 0.0
    private var lpX1 = 0.0, lpX2 = 0.0, lpY1 = 0.0, lpY2 = 0.0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let omega = 2 * Double.pi * 7500 / sampleRate
        let alpha = sin(omega) / 2  // Q = 1
        let cosw = cos(omega)
        let a0 = 1 + alpha
        lpB0 = ((1 - cosw) / 2) / a0
        lpB1 = (1 - cosw) / a0
        lpB2 = ((1 - cosw) / 2) / a0
        lpA1 = (-2 * cosw) / a0
        lpA2 = (1 - alpha) / a0
    }

    public var activeVoiceCount: Int { active.count }

    public func schedule(_ sound: PalSound) {
        for v in SoundRecipes.voices(for: sound) {
            scheduleVoice(v)
        }
    }

    public func scheduleVoice(_ v: SynthVoice) {
        let start = sampleTime + Int64(v.delay * sampleRate)
        var a = Active(voice: v, startSample: start)
        if let hp = v.highpass {
            a.configureHighpass(cutoff: hp, sampleRate: sampleRate)
        }
        active.append(a)
    }

    private func envelopeGain(_ env: [EnvPoint], at t: Double) -> Double {
        guard let first = env.first else { return 0 }
        if t <= first.t { return first.gain }
        for i in 1..<env.count {
            let p0 = env[i - 1], p1 = env[i]
            if t <= p1.t {
                let k = (t - p0.t) / max(p1.t - p0.t, 1e-9)
                if p1.exponential {
                    let g0 = max(p0.gain, 1e-6), g1 = max(p1.gain, 1e-6)
                    return g0 * pow(g1 / g0, k)
                }
                return p0.gain + (p1.gain - p0.gain) * k
            }
        }
        return 0
    }

    /// polyBLEP band-limited step correction.
    private func polyBLEP(_ t: Double, _ dt: Double) -> Double {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        } else if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    /// Render `frames` mono samples, additive, through the master chain.
    public func render(into out: UnsafeMutablePointer<Float>, frames: Int) {
        for f in 0..<frames {
            var sample = 0.0
            let now = sampleTime + Int64(f)
            var i = 0
            while i < active.count {
                let t = Double(now - active[i].startSample) / sampleRate
                if t < 0 { i += 1; continue }
                let v = active[i].voice
                if t > v.duration + 0.02 {
                    active.remove(at: i)
                    continue
                }
                var gain = envelopeGain(v.envelope, at: t)
                if v.amDepth > 0 {
                    // No clamp: WebAudio sums the LFO into the gain AudioParam, so
                    // the net gain can go negative — a polarity flip whose audible
                    // amplitude is |gain| (keeps the purr throbbing through the fade).
                    gain += v.amDepth * sin(active[i].amPhase * 2 * .pi)
                    active[i].amPhase += v.amRate / sampleRate
                }
                var value = 0.0
                if v.wave == .noise {
                    var r = active[i].rng
                    r ^= r << 13; r ^= r >> 7; r ^= r << 17
                    active[i].rng = r
                    value = Double(Int64(bitPattern: r) >> 11) / Double(1 << 52)
                    if v.highpass != nil {
                        let a = active[i]
                        let y = a.hpB0 * value + a.hpB1 * a.hpX1 + a.hpB2 * a.hpX2
                            - a.hpA1 * a.hpY1 - a.hpA2 * a.hpY2
                        active[i].hpX2 = a.hpX1
                        active[i].hpX1 = value
                        active[i].hpY2 = a.hpY1
                        active[i].hpY1 = y
                        value = y
                    }
                } else {
                    var freq = v.freq
                    if let f1 = v.freqEnd {
                        let k = min(t / max(v.freqRampDur, 1e-9), 1)
                        freq = v.freq * pow(f1 / max(v.freq, 1e-9), k)
                    }
                    if v.vibratoDepth != 0 {
                        freq += v.vibratoDepth * sin(active[i].vibPhase * 2 * .pi)
                        active[i].vibPhase += v.vibratoRate / sampleRate
                    }
                    let dt = freq / sampleRate
                    var phase = active[i].phase
                    switch v.wave {
                    case .square:
                        value = phase < 0.5 ? 1 : -1
                        value += polyBLEP(phase, dt)
                        value -= polyBLEP(fmod(phase + 0.5, 1), dt)
                    case .triangle:
                        value = 2 * abs(2 * phase - 1) - 1
                    case .sine:
                        value = sin(phase * 2 * .pi)
                    case .noise:
                        break
                    }
                    phase += dt
                    if phase >= 1 { phase -= 1 }
                    active[i].phase = phase
                }
                sample += value * gain
                i += 1
            }
            // master gain → low-pass
            sample *= masterGain
            let filtered = lpB0 * sample + lpB1 * lpX1 + lpB2 * lpX2 - lpA1 * lpY1 - lpA2 * lpY2
            lpX2 = lpX1; lpX1 = sample
            lpY2 = lpY1; lpY1 = filtered
            out[f] = Float(max(-1, min(1, filtered)))
        }
        sampleTime += Int64(frames)
    }
}
