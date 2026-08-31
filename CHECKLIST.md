# Pixel Pal — Behavior Checklist

Checked = implemented **and** verified (test, snapshot, or manual run noted in README).
File references: P = pip-timer-v4-3.jsx, M = mochi-timer.jsx.

## §1 Product principles
- [ ] 1.1 Every timer state expressed via body language/voice; numbers hidden most of the time
- [ ] 1.2 Settles/sleeps during work; wakes for milestones + final minute; never demands attention
- [ ] 1.3 Toy between sessions: drag, fling, pat, edge bounces
- [ ] 1.4 Idle/nap CPU < 2% (M1 pro); crisp integer pixels; no audio focus stealing; no Dock icon; zero network
- [ ] 1.5 No sprite rotation; axis-aligned squash only; nearest-neighbor; all drawing in 56×48 canvas

## §2 Tech stack
- [ ] 2.1 Swift 5.10+, AppKit shell, SwiftUI settings only
- [ ] 2.2 macOS 14 minimum; universal arm64+x86_64
- [ ] 2.3 `swift build` works; xcodegen project.yml provided
- [ ] 2.4 Only third-party dep: KeyboardShortcuts
- [ ] 2.5 LSUIElement; App Sandbox; Hardened Runtime
- [ ] 2.6 Target layout as specified

## §3 Floating window
- [ ] 3.1 NSPanel borderless/nonactivating, clear, no shadow, .floating, hidesOnDeactivate=false, canJoinAllSpaces+fullScreenAuxiliary+ignoresCycle
- [ ] 3.2 Panel = creature + ~60pt click-through margins + controls strip room
- [ ] 3.3 Click-through default; cursor-over-creature/strip enables interaction (~30 Hz); hold-⌥ mode; always-interactive mode
- [ ] 3.4 Position driven by physics via setFrameOrigin; drag feeds cursor into spring (P789-808)
- [ ] 3.5 Wall bounds = visibleFrame of current screen; didChangeScreenParameters clamps home; last position per screen remembered
- [ ] 3.6 Bare creature + breathing radial glow (0.35–0.65, ×0.45 asleep); no CRT stage by default; optional Cabinet setting
- [ ] 3.7 Hover controls strip, fade 300 ms; idle → 30s/5m/15m/25m + mute; running/paused → pause/resume, mute, reset; selected chip filled; chip style (mono 11pt uppercase, .12em, 3pt radius); visible while paused
- [ ] 3.8 Scroll over pal while idle: ±1 min/notch, clamp 1–90 min, blip (P347-360)

## §4 Rendering
- [ ] 4.1 56×48 RGBA8 → CALayer CGImage, .nearest, backingScale; 168×144 pt (3pt/px); integer at rest
- [ ] 4.2 Squash/stretch + scale as CATransform3D only during motion/impacts
- [ ] 4.3 Cadence: 60 fps (drag/flight/hop/celebrate/panic/particles/1.5s-after-state-change/cursor-near), 30 running/idle, 12 sleeping/loaf; paused when hidden/locked/display-asleep/terminating
- [ ] 4.4 Timer independent of frame cadence
- [ ] 4.5 Hearts row at (2+i·6, 2), max 8 (P628-629)
- [ ] 4.6 Clock 3×5 font centered x=28, y=2; shown idle/paused/hover/≤61s-running; hidden done; colon blinks 500 ms running; panic alternates RED/TXT 250 ms (P641-649)
- [ ] 4.7 Progress bar 20 segs 1×3 at (8+i·2, 41); ceil(frac·20); AMBER ≤60s; panic RED/AMBER 250 ms; pop #eafff3 / #fff3dd for 130 ms (P655-665)
- [ ] 4.8 Creature at bx=21(+wiggle/shake), by=20(P)/21(M)+bounce+lift(+variant offset)
- [ ] 4.9 Ground shadow row y=31, w=9−min(4, |lift|+max(0,−bounce)), hidden airborne (P677-681)
- [ ] 4.10 Milestone flash full-canvas primary 16% (P) / 15% (M) for 90 ms
- [ ] 4.11 3×5 font glyphs exactly as spec table; advance = width+1
- [ ] 4.12 Shared sprites HEART/MINI_HEART/Z/FEET_A/FEET_B/DANGLE_A/DANGLE_B exact

## §5 Timer core
- [ ] 5.1 idle|running|paused|done; endAt wall-clock; remaining = endAt − now
- [ ] 5.2 Presets 30s/5m/15m/25m (default 25m); custom scroll 1–90 min
- [ ] 5.3 Tap (<6 px, <450 ms): idle→start, running→pause, paused→resume, done→reset
- [ ] 5.4 Hold ≥450 ms (<6 px): PAT, never changes timer state
- [ ] 5.5 Tick per second on second boundary via DispatchSourceTimer; volume curve (≤10.5 → 1 + pitch ramp; ≤60 → (60−rem)/5; el<20 → 1; el<45 → fade; else 0)
- [ ] 5.6 Milestones once each: half (≥30 s dur), quarter (≥4 min), minute (>150 s, buzz, no hop); each: sound + 90 ms flash + hop(±) + wakeUntil = +2.6 s
- [ ] 5.7 Panic = running ∧ rem ≤ 10 s; Wiggle (Mochi) = running ∧ rem ≤ 3.5 s
- [ ] 5.8 Settle target rule (running, !hovered, !dragging, !flight, past wakeUntil, lastInteract>10 s, rem>75 s); rates 0.35/2.8 per s; sleeping = settle>0.6; sleepy/wake sounds; "!" 450 ms on wake
- [ ] 5.9 lastInteract updates: pointer move ≤300 pt, pointer down/drag, key/hotkey, wall impact
- [ ] 5.10 Bored = idle ∧ >30 s no interact → sit (P) / loaf pose (M), no fidgets
- [ ] 5.11 Finish: done mode; fanfare; confetti 28 + 16@600 ms; hop −46/−50; flyHeart @+900/+1100 ms; happyUntil +9/+10 s; banner YAY/NYA! 2.2 s AMBER/white 180 ms; celebrate hops (Pip, 650 ms); home → screen center; auto-reset 6.0/6.4 s; user notification
- [ ] 5.12 Abandon: reset with >15 s elapsed → sadUntil +5 s (Mochi + mrrp)
- [ ] 5.13 didWake recompute from endAt; deadline passed → quiet finish (fanfare 50%)
- [ ] 5.14 Unit tests: volume curve boundaries, milestones exactly once, settle timing, abandon, clock-jump correctness

## §6 Physics
- [ ] 6.1 Home spring 90/11; drag spring 380/26; Mochi zoomies 200/16; vel *= exp(−damp·dt)
- [ ] 6.2 Throw: speed>650 → flight (cap 2600); drag exp(−1.5dt); bounce visibleFrame, rest. 0.72, half-size 78; impact imp=clamp(v/1400,.2,1), scale=min(scale,1−.18imp), boing(imp); Mochi hiss imp>.55; exit <140 → home=pos clamped 90
- [ ] 6.3 Scale spring 240/13; hover 1.06; start impulse 0.8
- [ ] 6.4 Velocity squash st=clamp(speed·0.0004,0,.16); dominant 1+st, other 1−.6st
- [ ] 6.5 Hop: g=260 px/s²; impulses start −30, milestone −34, fidget −32, celebrate −34, finish −46/−50; landing (prev<−0.6→≥0): 100 ms squash + dust + thud
- [ ] 6.6 Walking speed>90 grounded: feet 130 ms alternate; top-half lean 1 px; held: dangle 260 ms, eyes down; worried >420
- [ ] 6.7 Breath periods (paused 5.5, idle 3.2, done 0.9/1.0, running lerp(3.2,1.0,p²), panic 0.45/0.5) ×(1+0.8·settle); bounce=round(sin·1.2) (panic 1.0/0.6 amp); none asleep/loaf
- [ ] 6.8 Idle fidgets every 8–17 s: Pip 35/25/25/15 wander/hop/glance/sway; Mochi 30/20/20/20/10 wander/hop/glance/stretch/ear-twitch
- [ ] 6.9 Reduce Motion: no hops/wiggle/shake/confetti/wander; breath ×0.35; squash ×0.3; sound unaffected

## §7 Personality
- [ ] 7.1 Blink 2.8–7.8 s (20% follow-up at 300 ms), 140 ms, 25% winks; none sleeping (P blinks can occur in panic per file; M excludes panic)
- [ ] 7.2 Gaze ≤300 pt: eox=clamp(round(gx/2.4)), eoy=clamp(round(gy/3)); ease 6/s toward 4 px max
- [ ] 7.3 Notice: wide eyes 250 ms (P) / ears perk + wide eyes 600 ms (M)
- [ ] 7.4 Pat: squint+blush+MINI_HEART (rise 7 px/s, life 1.1 s)+pat sound (P 900 ms; M slow-blink 0-250-800-1300 + purr 1450 ms cycle ≤1.5 s + blush)
- [ ] 7.5 Moods: happy (happyUntil, !panic, !sleeping) squint+blush+mouth; Mochi kneads (300 ms feet) when happy+idle+!walking; sad (sadUntil) flat eyes+frown (+M flat ears)
- [ ] 7.6 Hearts: 1/session; flight head→slot 900 ms, 7 px sine arc, then count++ + blip; row = today (≤8); lifetime in menu
- [ ] 7.7 Sleep: Zs every 1.7 s at (38,14), rise 3.5 px/s, life 1.8 s; canvas opacity 0.88; glow ×0.45
- [ ] 7.8 Pip panic: ±1 px shake/frame; wide 2×2 eyes; small mouth; red !! blink 400 ms; sweat (cyan 1×2) 0.9 s from (20,16) vx9 vy−6 g42 life .9
- [ ] 7.9 Confetti from (28,22): vx ±20, vy −30..−75, g 65, life 1.4–1.9, 5 colors cycle, removed y≥47

## §8 Characters
- [ ] 8.1 Pip palette/sprites/eyes/faces/ahoge/wake-"!"/sounds exact per file (P27-36, P55-80, P667-768)
- [ ] 8.2 Mochi palette, 5 body variants + selection rules, ears (4 states), whiskers/nose/mouth, tail chain (4 seg, targets: held 1.35, sleep −2.6, panic whip, content sway, travel lean; ease 8/s and 7−1.2i; tip #fff0d0; puffed in panic; sleep = dim 8 px line), hunt (crouch + locked wide eyes + flat ears, wiggle ±1 px 80 ms at ≤3.5 s, pounce −50 + 260 pt/s to center, zoomies 0.9–3.2 s sine 135 ms amplitude min(80, 0.18·w), loaf + happy face), kneading, cat sounds (meow/mew/trill/mrrp/purr/hiss) exact per file
- [ ] 8.3 Character switching (menu + settings), per-character engine state reset

## §9 Audio
- [ ] 9.1 ChipSynth: AVAudioEngine source node; master 0.5 → LPF 7.5 kHz; default device; mute = gain 0 persisted; sq envelope 4 ms attack, hold to 60%, linear release
- [ ] 9.2 All recipes: tick, bleep2, buzz, fanfare (+Pip 1567.98 layer), boing, thud, blip/pip, sleepy, wake, pat, meow, mew, trill, mrrp, purr (AM 23 Hz), hiss (HPF 2.6 kHz noise) — exact numbers
- [ ] 9.3 No audio focus stealing / exclusive behavior

## §10 Menu bar, hotkeys, settings, persistence
- [ ] 10.1 NSStatusItem: character pixel icon (template idle, tinted running) + optional remaining text
- [ ] 10.2 Menu: Start/Pause, Reset, presets, Custom…, Character ▸, Sound, Show/Hide Pal, Cabinet, Launch at Login, Settings…, Quit; hearts lifetime + streak shown
- [ ] 10.3 Global hotkey ⌃⌥Space via KeyboardShortcuts, configurable
- [ ] 10.4 SwiftUI Settings: character, sound+volume, menu-bar clock, interaction mode, cabinet, notifications, launch at login, hotkey recorder, reset hearts, About
- [ ] 10.5 Settings in UserDefaults (Codable); sessions.json in App Support {startedAt, durationMs, completed, character}; hearts today since local midnight; lifetime + streak in menu
- [ ] 10.6 UNUserNotificationCenter completion notification; permission requested lazily at first start
- [ ] 10.7 Handle multi-display, display sleep, screen lock, termination (save), Spaces

## §11 Packaging
- [ ] 11.1 Bundle id com.msull92.pixelpal; app Pixel Pal / PixelPal.app; cask token pixel-pal
- [ ] 11.2 build.sh (universal), notarize.sh (Developer ID + notarytool + staple), release.sh (zip + sha256)
- [ ] 11.3 Homebrew cask as specified + README brew install instructions
- [ ] 11.4 GitHub Actions release.yml: tag → build → sign/notarize if secrets else unsigned note → zip → sha256 → Release → tap bump PR
- [ ] 11.5 Ad-hoc signed local build; --no-quarantine documented

## §12 Quality bar
- [ ] 12.1 CPU: idle/nap <2%, running <4%, celebrate <12% (M1-class); numbers in README
- [ ] 12.2 Pixel-perfect 1×/2×; snapshot evidence for: idle, running-hidden-clock, panic, done-banner, sleeping, held, wall-impact, pat, sad, bored, mochi-nap, hunt-crouch, wiggle, zoomies, loaf
- [ ] 12.3 No dropped inputs (tap during hop/bounce counts)
- [ ] 12.4 Timer ±50 ms over 90 min incl. sleep/wake
- [ ] 12.5 Reduce Motion, Increase Contrast (optional), VoiceOver labels/values
- [ ] 12.6 Never steals focus; not in Cmd-Tab; not in Dock

## §13 Process
- [ ] 13.1 PLAN.md written from full prototype read
- [ ] 13.2 This checklist maintained
- [ ] 13.3 Milestone commits M1–M7
- [ ] 13.4 Build+test+launch+screenshot after every milestone
- [ ] 13.5 No extra features before M7; no simplified behaviors
- [ ] 13.6 git clone && ./Packaging/build.sh → PixelPal.app; swift test passes; README complete
