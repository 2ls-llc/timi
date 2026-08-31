import AVFoundation
import TimiKit

/// AVAudioEngine host for the Kit's SynthDSP. One mono source node → main mixer
/// → default output. Never claims exclusive access, never ducks other audio.
/// The engine pauses itself a few seconds after the last voice ends so an idle
/// pal costs no audio CPU.
final class ChipSynth: SoundSink {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode!
    private let dsp: SynthDSP
    private let lock = NSLock()
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
            self.lock.lock()
            self.dsp.render(into: ptr, frames: Int(frameCount))
            self.lock.unlock()
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
        lock.lock()
        for v in voices { dsp.scheduleVoice(v) }
        lock.unlock()
        lastPlay = Date()
        if !engine.isRunning {
            try? engine.start()
        }
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
        lock.lock()
        dsp.masterGain = muted ? 0 : 0.5 * volume
        lock.unlock()
    }

    private func pauseIfIdle() {
        guard engine.isRunning, Date().timeIntervalSince(lastPlay) > 3 else { return }
        lock.lock()
        let idle = dsp.activeVoiceCount == 0
        lock.unlock()
        if idle {
            engine.pause()
        }
    }
}
