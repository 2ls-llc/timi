import AVFoundation
import os
import TimiKit

/// AVAudioEngine host for the Kit's SynthDSP. One mono source node → main mixer
/// → default output. Never claims exclusive access, never ducks other audio.
/// The engine pauses itself a few seconds after the last voice ends so an idle
/// pal costs no audio CPU.
final class ChipSynth: SoundSink {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode!
    private let dsp: SynthDSP
    /// Guards `dsp` between the main thread and the real-time render thread.
    /// An unfair lock donates priority to the holder, so the I/O thread is never
    /// stranded behind a deprioritized main thread; critical sections are tiny.
    private let lock = OSAllocatedUnfairLock()
    private var muted = false
    private var volume = 1.0
    private var lastPlay = Date.distantPast
    private var idleTimer: Timer?

    init() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        dsp = SynthDSP(sampleRate: sampleRate > 0 ? sampleRate : 44100)
        applyGain()

        let format = AVAudioFormat(standardFormatWithSampleRate: dsp.sampleRate, channels: 1)!
        source = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let ptr = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            self.lock.withLock {
                self.dsp.render(into: ptr, frames: Int(frameCount))
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)

        idleTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pauseIfIdle()
        }
    }

    func play(_ sound: PalSound) {
        if muted { return }
        // A silent tick (volume ≤ 0.01) produces no voices — don't touch the
        // engine or the idle clock for it, or the engine never pauses in flow.
        let voices = SoundRecipes.voices(for: sound)
        guard !voices.isEmpty else { return }
        if !engine.isRunning {
            // No output device (or a start failure): drop the sound instead of
            // queueing it to burst out the moment a device appears.
            do { try engine.start() } catch { return }
        }
        lock.withLock {
            for v in voices { dsp.scheduleVoice(v) }
        }
        lastPlay = Date()
    }

    func setMuted(_ muted: Bool) {
        self.muted = muted
        applyGain()
    }

    func setVolume(_ volume: Double) {
        self.volume = clamp(volume, 0, 1)
        applyGain()
    }

    private func applyGain() {
        let gain = muted ? 0 : 0.5 * volume
        lock.withLock { dsp.masterGain = gain }
    }

    private func pauseIfIdle() {
        guard engine.isRunning, Date().timeIntervalSince(lastPlay) > 3 else { return }
        let idle = lock.withLock { dsp.activeVoiceCount == 0 }
        if idle {
            engine.pause()
        }
    }
}
