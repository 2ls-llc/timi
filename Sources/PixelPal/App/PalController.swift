import AppKit
import PixelPalKit

protocol SoundSink: AnyObject {
    func play(_ sound: PalSound)
    func setMuted(_ muted: Bool)
    func setVolume(_ volume: Double)
}

/// Placeholder sink until ChipSynth lands (M3).
final class NullSoundSink: SoundSink {
    func play(_ sound: PalSound) {}
    func setMuted(_ muted: Bool) {}
    func setVolume(_ volume: Double) {}
}

/// Orchestrates TimerCore + PalEngine + panel + layers + input + cadence.
/// Everything runs on the main thread.
final class PalController: NSObject, PalViewDelegate {
    let timer = TimerCore()
    private(set) var engine: PalEngine
    let panel = PalPanel()
    let palView = PalView(frame: NSRect(origin: .zero, size: PanelGeometry.size))
    var sound: SoundSink = NullSoundSink()
    let settingsStore: SettingsStore
    var settings: AppSettings { settingsStore.settings }
    let notifier = Notifier()

    /// Hooks the app layer (status bar, persistence, notifications) plugs into.
    var onModeChanged: (() -> Void)?
    var onSessionStarted: (() -> Void)?
    var onSessionCompleted: (() -> Void)?
    var onHeartLanded: (() -> Void)?

    private var displayLink: CADisplayLink?
    private var lastFrameT: Double?
    private var canvas = PixelCanvas()
    private var lastCursor = NSPoint(x: -1e9, y: -1e9)
    private var lastModeChangeT = -1e9
    private var lastMode: TimerMode = .idle
    private var tickTimer: DispatchSourceTimer?
    private var autoResetWork: DispatchWorkItem?
    private var currentFPS: Float = 0
    private var glowImages: [CharacterID: CGImage] = [:]
    private(set) var controlsStrip: ControlsStrip?

    /// DebugHarness only: force the hovered flag for scripted verification.
    var debugHoverOverride: Bool?

    private var nowMs: Double { CACurrentMediaTime() * 1000 }
    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        let config = CharacterConfig.config(for: settingsStore.settings.character)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Prototype home: (w·0.5, h·0.45 from the top).
        let home = Vec2(screen.midX, screen.minY + screen.height * 0.55)
        engine = PalEngine(config: config, seed: UInt64.random(in: .min ... .max),
                           tMs: CACurrentMediaTime() * 1000, home: home, hearts: 0)
        timer.setDuration(ms: settingsStore.settings.lastDurationMs)
        super.init()

        panel.contentView = palView
        palView.delegate = self

        let strip = ControlsStrip(frame: PanelGeometry.stripRect)
        strip.controller = self
        palView.addSubview(strip)
        controlsStrip = strip

        palView.onAccessibilityPress = { [weak self] in self?.tapAction() }
        refreshAccessibility()

        updateGlowImage()
        panel.setFrameOrigin(PanelGeometry.panelOrigin(forCreatureAt: engine.pos))
    }

    func startRunning() {
        sound.setMuted(settings.muted)
        sound.setVolume(settings.volume)
        applyCabinetLook()
        if settings.palVisible {
            panel.orderFrontRegardless()
        }
        let link = palView.displayLink(target: self, selector: #selector(frameTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        displayLink?.isPaused = !settings.palVisible
        applyCadence(60)
    }

    // MARK: - Frame loop

    @objc private func frameTick(_ link: CADisplayLink) {
        let tMs = nowMs
        let dt = lastFrameT.map { (tMs - $0) / 1000 } ?? 0
        lastFrameT = tMs
        let wallNow = Date()

        // Timer catch-up (the DispatchSourceTimer path handles exact tick timing;
        // this is idempotent belt-and-braces, like the prototype's frame check).
        handleTimerEvents(timer.advance(now: wallNow), tMs: tMs)

        if timer.mode != lastMode {
            lastMode = timer.mode
            lastModeChangeT = tMs
            controlsStrip?.modeChanged()
            onModeChanged?()
        }

        let cursor = NSEvent.mouseLocation
        let cursorMoved = hypot(cursor.x - lastCursor.x, cursor.y - lastCursor.y) > 0.5
        lastCursor = cursor
        let hovered = computeHovered(cursor: cursor)
        updateClickThrough(cursor: cursor, hovered: hovered)

        let screenRect = currentScreenRect()
        let input = EngineInput(
            tMs: tMs, dt: dt, mode: timer.mode,
            durationMs: timer.durationMs,
            remainingMs: timer.remainingMs(now: wallNow),
            cursor: Vec2(cursor.x, cursor.y),
            cursorMoved: cursorMoved, hovered: hovered,
            reduceMotion: reduceMotion, screen: screenRect)
        let result = engine.step(input)
        for s in result.sounds { sound.play(s) }
        for e in result.events {
            if case .heartLanded = e { onHeartLanded?() }
        }

        Renderer.draw(into: &canvas, engine: engine)
        applyToLayers()

        let origin = PanelGeometry.panelOrigin(forCreatureAt: engine.pos)
        if abs(origin.x - panel.frame.origin.x) > 0.05 || abs(origin.y - panel.frame.origin.y) > 0.05 {
            panel.setFrameOrigin(origin)
        }

        controlsStrip?.updateVisibility(hovered: hovered, mode: timer.mode, tMs: tMs)
        updateCadence(hovered: hovered, cursor: cursor, tMs: tMs)

        // VoiceOver value: refresh when the displayed second changes.
        let axSecond = Int(input.remainingMs / 1000)
        if axSecond != lastAxSecond || timer.mode != lastAxMode {
            lastAxSecond = axSecond
            lastAxMode = timer.mode
            refreshAccessibility()
        }
    }

    private var lastAxSecond = -1
    private var lastAxMode: TimerMode = .idle

    private func refreshAccessibility() {
        palView.axLabel = "\(engine.config.name) — pixel pal timer"
        let now = Date()
        switch timer.mode {
        case .idle:
            palView.axValue = "idle, \(formatMillis(timer.durationMs)) set"
        case .running:
            palView.axValue = "running, \(formatMillis(timer.remainingMs(now: now))) remaining"
        case .paused:
            palView.axValue = "paused, \(formatMillis(timer.remainingMs(now: now))) remaining"
        case .done:
            palView.axValue = "finished"
        }
    }

    private var lastCanvasBuffer: [UInt8] = []
    private var lastScaleX = CGFloat.nan
    private var lastScaleY = CGFloat.nan
    private var lastCanvasOpacity = Float.nan
    private var lastGlowOpacity = Float.nan

    private func applyToLayers() {
        let f = engine.flags
        // Only touch Core Animation when something actually changed — at rest a
        // frame is often byte-identical (memcmp of 10.5 KB is ~free) and skipping
        // the commit skips the render-server round trip entirely.
        let canvasChanged = canvas.buffer != lastCanvasBuffer
        let sx = CGFloat(f.sxc * engine.scale)
        let sy = CGFloat(f.syc * engine.scale)
        let canvasOp = Float(f.canvasOpacity)
        let glowOp = Float(f.glowOpacity)
        let transformChanged = abs(sx - lastScaleX) > 0.0005 || abs(sy - lastScaleY) > 0.0005
        // 0.01 opacity steps are invisible on the soft glow but skip ~2/3 of
        // otherwise-idle render-server commits.
        let opacityChanged = abs(canvasOp - lastCanvasOpacity) > 0.01 ||
            abs(glowOp - lastGlowOpacity) > 0.01
        guard canvasChanged || transformChanged || opacityChanged else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if canvasChanged {
            lastCanvasBuffer = canvas.buffer
            if let img = CanvasImage.make(from: canvas) {
                palView.canvasLayer.contents = img
            }
        }
        if transformChanged {
            lastScaleX = sx
            lastScaleY = sy
            palView.canvasLayer.transform = CATransform3DMakeScale(sx, sy, 1)
        }
        if opacityChanged {
            lastCanvasOpacity = canvasOp
            lastGlowOpacity = glowOp
            palView.canvasLayer.opacity = canvasOp
            palView.glowLayer.opacity = glowOp
        }
        CATransaction.commit()
    }

    // MARK: - Hover & click-through

    private func panelPoint(from screenPoint: NSPoint) -> NSPoint {
        NSPoint(x: screenPoint.x - panel.frame.origin.x,
                y: screenPoint.y - panel.frame.origin.y)
    }

    private func computeHovered(cursor: NSPoint) -> Bool {
        if let forced = debugHoverOverride { return forced }
        let p = panelPoint(from: cursor)
        if PanelGeometry.creatureRect.contains(p) { return true }
        if let strip = controlsStrip, !strip.isHidden, strip.alphaValue > 0.01,
           strip.frame.contains(p) { return true }
        return false
    }

    private func updateClickThrough(cursor: NSPoint, hovered: Bool) {
        let interactive: Bool
        if engine.dragging {
            interactive = true
        } else {
            switch settings.interactionMode {
            case .hover: interactive = hovered
            case .holdOption: interactive = NSEvent.modifierFlags.contains(.option)
            case .always: interactive = true
            }
        }
        if panel.ignoresMouseEvents == interactive {
            panel.ignoresMouseEvents = !interactive
        }
    }

    private func currentScreenRect() -> PixelPalKit.Rect {
        let p = NSPoint(x: engine.pos.x, y: engine.pos.y)
        let screen = NSScreen.screens.first { NSPointInRect(p, $0.frame) }
            ?? panel.screen ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return PixelPalKit.Rect(x: vf.origin.x, y: vf.origin.y, w: vf.width, h: vf.height)
    }

    // MARK: - Cadence policy (§4)

    private func updateCadence(hovered: Bool, cursor: NSPoint, tMs: Double) {
        let cursorNear = hypot(cursor.x - engine.pos.x, cursor.y - engine.pos.y) < 300
        let recentChange = tMs - lastModeChangeT < 1500
        let f = engine.flags
        let fps: Float
        if engine.wantsHighCadence || hovered || cursorNear || recentChange {
            fps = 60
        } else if f.sleepingNow || f.bored || f.loaf {
            fps = 12
        } else {
            fps = 30
        }
        applyCadence(fps)
    }

    private func applyCadence(_ fps: Float) {
        guard fps != currentFPS, let link = displayLink else { return }
        currentFPS = fps
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: min(12, fps), maximum: fps, preferred: fps)
    }

    func setPaused(_ paused: Bool) {
        displayLink?.isPaused = paused
        if paused { lastFrameT = nil }
    }

    // MARK: - Pointer input (PalViewDelegate)

    func palViewMouseDown(at screenPoint: NSPoint) {
        let p = panelPoint(from: screenPoint)
        guard PanelGeometry.creatureRect.contains(p) else { return }
        engine.pointerDown(at: Vec2(screenPoint.x, screenPoint.y), tMs: nowMs)
    }

    func palViewMouseDragged(to screenPoint: NSPoint) {
        engine.pointerDragged(to: Vec2(screenPoint.x, screenPoint.y), tMs: nowMs)
    }

    func palViewMouseUp() {
        let tMs = nowMs
        switch engine.pointerUp(tMs: tMs) {
        case .tap:
            tapAction()
        case .pat:
            if let s = engine.config.patSound { sound.play(s) }
        case .flung, .settled, .none:
            break
        }
    }

    private var scrollAccum: CGFloat = 0

    func palViewScrolled(deltaY: CGFloat, precise: Bool) {
        guard timer.mode == .idle else { return }
        engine.noteInteraction(tMs: nowMs)
        var steps = 0
        if precise {
            scrollAccum += deltaY
            while scrollAccum >= 30 { steps += 1; scrollAccum -= 30 }
            while scrollAccum <= -30 { steps -= 1; scrollAccum += 30 }
        } else if deltaY != 0 {
            steps = deltaY > 0 ? 1 : -1
        }
        guard steps != 0 else { return }
        // Scroll up = more time (prototype: wheel up = +1 min), ±1 min per notch.
        if timer.nudgeDuration(byMinutes: steps) {
            sound.play(.blip)
        }
    }

    // MARK: - Timer actions

    func tapAction() {
        let tMs = nowMs
        engine.noteInteraction(tMs: tMs)
        switch timer.tap(now: Date()) {
        case .started:
            sessionDidStart(tMs: tMs)
        case .paused:
            engine.config.sounds(for: .pause).forEach { sound.play($0) }
            cancelTickTimer()
        case .resumed:
            engine.config.sounds(for: .resume).forEach { sound.play($0) }
            scheduleTickTimer()
        case .reset:
            cancelAutoReset()
        }
    }

    func resetAction() {
        let tMs = nowMs
        engine.noteInteraction(tMs: tMs)
        let abandoned = timer.reset(now: Date())
        if abandoned {
            engine.onAbandon(tMs: tMs)
            engine.config.sounds(for: .abandon).forEach { sound.play($0) }
        }
        cancelTickTimer()
        cancelAutoReset()
    }

    func toggleMute() {
        setSound(on: settings.muted)
    }

    func setSound(on: Bool) {
        settingsStore.update { $0.muted = !on }
        sound.setMuted(!on)
        controlsStrip?.refreshChips()
    }

    func setVolume(_ volume: Double) {
        settingsStore.update { $0.volume = clamp(volume, 0, 1) }
        sound.setVolume(settings.volume)
    }

    func setShowMenuBarClock(_ show: Bool) {
        settingsStore.update { $0.showMenuBarClock = show }
    }

    func setInteractionMode(_ mode: InteractionMode) {
        settingsStore.update { $0.interactionMode = mode }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        settingsStore.update { $0.notificationsEnabled = enabled }
    }

    func setCabinet(_ on: Bool) {
        settingsStore.update { $0.cabinetFrame = on }
        applyCabinetLook()
    }

    private func applyCabinetLook() {
        let on = settings.cabinetFrame
        palView.cabinetLayer.isHidden = !on
        palView.scanlineLayer.isHidden = !on
        if on {
            let size = palView.cabinetLayer.frame.size
            palView.cabinetLayer.contents = CabinetImages.background(for: engine.config.id, size: size)
            palView.scanlineLayer.contents = CabinetImages.scanlines(size: size)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        settingsStore.update { $0.launchAtLogin = on }
        LoginItem.set(enabled: on)
    }

    func pickDuration(ms: Double) {
        guard timer.mode == .idle else { return }
        engine.noteInteraction(tMs: nowMs)
        timer.setDuration(ms: ms)
        settingsStore.update { $0.lastDurationMs = ms }
        sound.play(.blip)
        controlsStrip?.refreshChips()
    }

    private func sessionDidStart(tMs: Double) {
        engine.onStart(tMs: tMs, reduceMotion: reduceMotion)
        engine.config.sounds(for: .start).forEach { sound.play($0) }
        scheduleTickTimer()
        notifier.requestPermissionIfNeeded(enabled: settings.notificationsEnabled)
        onSessionStarted?()
    }

    private func handleTimerEvents(_ events: [TimerEvent], tMs: Double) {
        for event in events {
            switch event {
            case .tick(let volume, let pitch):
                sound.play(.tick(volume: volume, pitch: pitch))
            case .milestone(let m):
                engine.onMilestone(m, tMs: tMs, reduceMotion: reduceMotion)
                let moment: TimerSoundMoment = m == .half ? .half : m == .quarter ? .quarter : .minute
                engine.config.sounds(for: moment).forEach { sound.play($0) }
            case .finished(let quiet):
                engine.onFinish(tMs: tMs, reduceMotion: reduceMotion)
                sound.play(.fanfare(volume: quiet ? 0.5 : 1,
                                    pipTopNote: engine.config.id == .pip))
                cancelTickTimer()
                scheduleAutoReset()
                notifier.notifyCompletion(characterName: engine.config.name,
                                          durationMs: timer.durationMs,
                                          enabled: settings.notificationsEnabled)
                onSessionCompleted?()
            }
        }
    }

    // MARK: - Tick scheduling (second boundaries + milestone instants + finish)

    private func scheduleTickTimer() {
        cancelTickTimer()
        guard let deadline = timer.nextDeadline(now: Date()) else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + max(0, deadline.timeIntervalSinceNow),
                   leeway: .milliseconds(15))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.handleTimerEvents(self.timer.advance(now: Date()), tMs: self.nowMs)
            if self.timer.mode == .running { self.scheduleTickTimer() }
        }
        t.resume()
        tickTimer = t
    }

    private func cancelTickTimer() {
        tickTimer?.cancel()
        tickTimer = nil
    }

    private func scheduleAutoReset() {
        cancelAutoReset()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.timer.mode == .done else { return }
            self.timer.reset(now: Date())
        }
        autoResetWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + engine.config.autoResetMs / 1000, execute: work)
    }

    private func cancelAutoReset() {
        autoResetWork?.cancel()
        autoResetWork = nil
    }

    // MARK: - System events

    /// NSWorkspace.didWakeNotification: recompute from endAt; a deadline that passed
    /// during sleep finishes quietly.
    func systemDidWake() {
        handleTimerEvents(timer.advance(now: Date(), context: .wake), tMs: nowMs)
        if timer.mode == .running { scheduleTickTimer() }
    }

    func screensChanged() {
        let rect = currentScreenRect()
        engine.home = Physics.clampHome(engine.home, in: rect)
        engine.pos = Physics.clampHome(engine.pos, in: rect)
    }

    // MARK: - Character switching

    func switchCharacter(to id: CharacterID) {
        guard id != engine.config.id else { return }
        settingsStore.update { $0.character = id }
        let old = engine
        engine = PalEngine(config: .config(for: id),
                           seed: UInt64.random(in: .min ... .max),
                           tMs: nowMs, home: old.home, hearts: old.hearts)
        engine.pos = old.pos
        updateGlowImage()
        applyCabinetLook()
        controlsStrip?.characterChanged()
    }

    func setHearts(_ n: Int) {
        engine.hearts = n
    }

    private func updateGlowImage() {
        let id = engine.config.id
        if glowImages[id] == nil {
            glowImages[id] = GlowImage.make(tint: engine.config.glowTint,
                                            size: PanelGeometry.glowSize)
        }
        palView.glowLayer.contents = glowImages[id]
    }

    // MARK: - Visibility

    func setPalVisible(_ visible: Bool) {
        settingsStore.update { $0.palVisible = visible }
        if visible {
            panel.orderFrontRegardless()
            setPaused(false)
        } else {
            panel.orderOut(nil)
            setPaused(true)
        }
    }
}
