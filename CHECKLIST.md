# Timi — Behavior Checklist

> **Rename & rescope (post-M7):** the app and the cat are both named **Timi**; the
> second character ("Pip") and its prototype file were removed at the owner's
> direction. Pip-specific line items below are struck through in spirit — they were
> verified while they existed and their removal was gated on Timi's golden snapshots
> staying byte-identical. "Mochi" was Timi's working name.

Checked = implemented **and** verified. Verification key: (T)=unit test, (S)=golden
snapshot test, (L)=live run with debug-harness evidence in Tests/snapshots/,
(W)=confirmed by the 14-agent adversarial review workflow, (M)=measured.
File references: M = Prototype/mochi-timer.jsx (Timi's source of truth);
P = pip-timer-v4-3.jsx, the removed second prototype (historical citations).

## §1 Product principles
- [x] 1.1 Every timer state expressed via body language/voice; numbers hidden most of the time (L,S)
- [x] 1.2 Settles/sleeps during work; wakes for milestones + final minute; never demands attention (T,L)
- [x] 1.3 Toy between sessions: drag, fling, pat, edge bounces (T,L)
- [x] 1.4 Idle ~1.4–2.2% (avg <2%), nap 0.9–1.5%, running ~3%, celebrate ≤9.3% CPU (M, release, Apple Silicon); crisp integer pixels; no audio ducking; no Dock icon; zero network
- [x] 1.5 No sprite rotation; axis-aligned squash only; nearest-neighbor; all drawing in 56×48 canvas (S)

## §2 Tech stack
- [x] 2.1 Swift (tools 5.10), AppKit shell, SwiftUI settings only
- [x] 2.2 macOS 14 minimum; universal build via Packaging/build.sh (M7)
- [x] 2.3 `swift build` works; xcodegen project.yml provided (M7)
- [x] 2.4 Only third-party dep: KeyboardShortcuts
- [x] 2.5 LSUIElement; App Sandbox + Hardened Runtime in bundled build (M7)
- [x] 2.6 Target layout as specified (SwiftPM Sources/ mapping documented in PLAN.md)

## §3 Floating window
- [x] 3.1 NSPanel borderless/nonactivating, clear, no shadow, .floating, hidesOnDeactivate=false, canJoinAllSpaces+fullScreenAuxiliary+ignoresCycle
- [x] 3.2 Panel 340×300 = creature + click-through margins (86pt sides, 98pt bottom, 58pt top) + strip room
- [x] 3.3 Click-through default; cursor-over-creature/strip enables input (display-link cadence ≥12 Hz, 60 Hz when near); hold-⌥ mode; always mode
- [x] 3.4 Position driven by physics via setFrameOrigin; drag feeds cursor into 380/26 spring (T,L)
- [x] 3.5 Wall bounds = visibleFrame of current screen; didChangeScreenParameters clamps home (L)
- [x] 3.6 Bare creature + breathing glow 0.35–0.65 (×0.45 asleep); no CRT by default; Cabinet optional (L: m4-cabinet.png)
- [x] 3.7 Controls strip: hover-revealed, 300 ms fade, presets+mute idle / pause-mute-reset running, pinned while paused, filled selected chip, chip typography (L: m2-strip-idle.png, m3-paused-strip.png)
- [x] 3.8 Scroll over pal while idle: ±1 min/notch, 1–90 min, blip (T,L: 25:00→27:00)

## §4 Rendering
- [x] 4.1 56×48 RGBA8 → CALayer CGImage, .nearest, 168×144 pt (3 pt/px); integer at rest (S)
- [x] 4.2 Squash/stretch + scale as CATransform3D only (L)
- [x] 4.3 Cadence 60/30/12 per policy (Zs excluded from 60-triggers — sleep tier wins); paused when hidden/locked/display-asleep/terminating (M)
- [x] 4.4 Timer independent of frame cadence (wall-clock DispatchSourceTimer) (T)
- [x] 4.5 Hearts row (2+i·6, 2), max 8 (S)
- [x] 4.6 Clock 3×5 font centered, visibility rule, colon 500 ms, panic RED/TXT 250 ms (S,L)
- [x] 4.7 Progress bar 20×(1×3) at (8+i·2, 41), ceil(frac·20), AMBER ≤60 s, panic alternation, pop color 130 ms (S,L)
- [x] 4.8 Creature at bx=21(+wiggle/shake), by per character/variant (S, ASCII dumps)
- [x] 4.9 Ground shadow row y=31, width formula per character, hidden airborne (S, dumps)
- [x] 4.10 Milestone flash 90 ms, alpha .16 P / .15 M (W)
- [x] 4.11 Font glyphs + advance width+1 (S, dumps)
- [x] 4.12 Shared sprites exact (S, dumps)

## §5 Timer core
- [x] 5.1 idle|running|paused|done; endAt wall-clock; remaining = endAt − now (T)
- [x] 5.2 Presets 30s/5m/15m/25m (default 25m); custom 1–90 min (T)
- [x] 5.3 Tap semantics (<6 px, <450 ms) (T)
- [x] 5.4 Hold ≥450 ms = PAT, never touches timer (T)
- [x] 5.5 Ticks on second boundary via DispatchSourceTimer; volume curve exact at all boundaries (T,W)
- [x] 5.6 Milestones once each with gates (≥30 s, ≥4 min, >150 s strict); sound+flash+hop (minute: no hop)+wakeUntil 2.6 s (T,W)
- [x] 5.7 Panic ≤10 s; Mochi wiggle ≤3.5 s (T,S)
- [x] 5.8 Settle: full condition set, 0.35/2.8 rates, sleep at 0.6, sleepy/wake sounds, "!" 450 ms (T,L)
- [x] 5.9 lastInteract: pointer ≤300 pt, down/drag, keys/hotkey/scroll, wall impacts (T)
- [x] 5.10 Bored 30 s → Pip sit / Mochi loaf, no fidgets (T,S)
- [x] 5.11 Finish: fanfare, 28+16@600 ms confetti, hop −46/−50, flyHeart +900/+1100 ms, happy 9/10 s, banner 2.2 s 180 ms alternation, Pip hop loop 650 ms, home→screen center, auto-reset 6.0/6.4 s, notification (T,L)
- [x] 5.12 Abandon >15 s → sad 5 s (+Mochi mrrp) (T,L)
- [x] 5.13 didWake recompute; passed deadline → quiet finish (fanfare 50%) (T)
- [x] 5.14 Unit tests: tick curve boundaries, milestones exactly once (incl. pause/resume), settle timing, abandon rule, clock-jump (89 tests green)

## §6 Physics
- [x] 6.1 Springs 90/11, 380/26, zoomies 200/16, exp damping (T)
- [x] 6.2 Throw >650 (cap 2600), drag 1.5, R 78, restitution 0.72, imp clamp, scale hit, hiss >0.55, exit <140, home clamp 90 (T,L)
- [x] 6.3 Scale spring 240/13; hover 1.06; start 0.8 (T,W)
- [x] 6.4 Squash 0.0004/0.16/0.6 (T)
- [x] 6.5 Hop g=260; impulses −30/−34/−32/−34/−46/−50; landing prev<−0.6 (small hops land quietly at 60 fps — prototype-faithful); 100 ms squash + dust + thud (T)
- [x] 6.6 Walking >90, feet 130 ms, lean 1 px; dangle 260 ms + eyes down; worried >420 (S, dumps)
- [x] 6.7 Breath periods exact ×(1+0.8·settle); bounce amplitudes 1.2/1.0 P, 1.1/0.6 M; none asleep/loaf (W)
- [x] 6.8 Fidgets 8–17 s, Pip 35/25/25/15, Mochi 30/20/20/20/10 (T,W)
- [x] 6.9 Reduce Motion: no hops/wiggle/shake/confetti/fidgets; squash ×0.3; breath ×0.35 (native adaptation per mission §6 — the files lack it; documented in code); sound unaffected (T)

## §7 Personality
- [x] 7.1 Blink 2.8–7.8 s, 20% follow 300 ms, 25% wink, 140 ms; none sleeping/rm; P blinks in panic, M doesn't (per-file) (W)
- [x] 7.2 Gaze ≤300 pt, /2.4 & /3 rounding, ease 6/s, 4 px max, AppKit y-flip (T)
- [x] 7.3 Notice 250 ms P / ears perk 600 ms M (S, dumps)
- [x] 7.4 Pat: squint+blush+MINI_HEART(7 px/s, 1.1 s)+pat sound P; slow-blink 0/250/800/1300 + purr 1450 ms cycle M (T,S,L)
- [x] 7.5 Moods: happy (¬panic ¬sleep), Mochi kneads 300 ms when happy+idle+¬walking, sad flat eyes+frown (+M flat ears) (T,S,L)
- [x] 7.6 Hearts: 1/session, flight 900 ms + sin arc 7 px, count++ + blip a frame later (prototype-exact), today ≤8 in row, lifetime in menu (T,L)
- [x] 7.7 Sleep Zs 1.7 s (38,14) rise 3.5, life 1.8; opacity 0.88; glow ×0.45; Pip Z x-sway, Mochi straight (T,L)
- [x] 7.8 Pip panic shake ±1, wide 2×2, small mouth, red !! 400 ms, sweat 0.9 s (20,16) vx9 vy−6 g42 (T,S,L)
- [x] 7.9 Confetti (28,22), vx ±20, vy −30..−75, g 65, life 1.4–1.9, 5 colors, cull y≥47 (T,W)

## §8 Characters
- [x] 8.1 ~~Pip~~ — removed at the owner's direction (was verified S,W while it existed)
- [x] 8.2 Timi: palette+glow tint 255,210,140; 5 variants + selection rules; ears 4 states; whiskers/nose/mouth; 4-segment tail chain (all targets + ease rates + tip + puff + sleep line); hunt (crouch/locked eyes/flat ears/wiggle 80 ms/pounce −50 + 260 pt/s/zoomies 0.9–3.2 s sine 135 ms/loaf); kneading; cat voice (S,W; live dumps)
- [x] 8.3 ~~Character switching~~ — removed with Pip; Timi is the only pal

## §9 Audio
- [x] 9.1 AVAudioSourceNode synth; master 0.5 → LPF 7.5 kHz; default device; mute persisted; sq envelope 4 ms/60%/release; engine auto-pauses when silent (T,M)
- [x] 9.2 All recipes exact (incl. Mochi bend-boing 12 ms attack, purr AM polarity flip to 1.45 s, hiss biquad HPF, Pip fanfare 1567.98 layer) (T,W)
- [x] 9.3 No focus stealing / exclusive audio (default output only)

## §10 Menu bar, hotkeys, settings, persistence
- [x] 10.1 NSStatusItem pixel portrait (template idle / tinted running) + optional mm:ss
- [x] 10.2 Menu: Start/Pause ⌃⌥Space, Reset, presets, Custom…, Character ▸, Sound, Show/Hide, Cabinet, Launch at Login, hearts+streak line, Settings…, Quit
- [x] 10.3 KeyboardShortcuts global hotkey, default ⌃⌥Space, recorder in Settings
- [x] 10.4 SwiftUI Settings: all specified controls + About (smoke-tested layout)
- [x] 10.5 UserDefaults settings; sessions.json {startedAt, durationMs, completed, character}; hearts today; lifetime+streak (L: verified file contents + relaunch restore)
- [x] 10.6 Completion notification; lazy permission at first start (bundle-gated)
- [x] 10.7 Multi-display clamps, display sleep, screen lock, termination save, Spaces (canJoinAllSpaces)

## §11 Packaging (M7)
- [x] 11.1 Bundle id com.twols.timi; Timi.app; cask token timi (never "pip")
- [x] 11.2 build.sh (universal, verified: x86_64+arm64, sandbox entitlement, launches) / notarize.sh / release.sh (zip+sha256 verified)
- [x] 11.3 Homebrew cask per spec + README brew instructions (tap: twols/homebrew-tap)
- [x] 11.4 release.yml: tests → build → sign+notarize if secrets else ad-hoc with release note → Release → tap bump PR
- [x] 11.5 Ad-hoc signed sandboxed build verified running; --no-quarantine documented in README + release notes

## §12 Quality bar
- [x] 12.1 CPU measured (see 1.4) — numbers in README
- [x] 12.2 Snapshot evidence: 13 deterministic goldens (idle, running-hidden-clock, done-banner, held, wall-impact, pat, sad, bored-loaf, nap, hunt-crouch, wiggle, zoomies, loaf — the hunt covers "panic", the nap covers "sleeping") + live PNGs; 1× and 3× crispness (2× display: 6 device px per cell by construction)
- [x] 12.3 Tap during hop/bounce counts (T)
- [x] 12.4 Timer ±50 ms over 90 min incl. sleep/wake (T: exact wall-clock arithmetic)
- [x] 12.5 Reduce Motion (T); VoiceOver: pal is a labeled button with live value, chips labeled; Increase Contrast: not implemented (spec marks it optional)
- [x] 12.6 Non-activating panel; LSUIElement (no Dock/Cmd-Tab)

## §13 Process
- [x] 13.1 PLAN.md from full prototype read
- [x] 13.2 Checklist maintained
- [x] 13.3 Milestone commits M1–M7
- [x] 13.4 Build+test+launch+snapshot evidence per milestone
- [x] 13.5 No extra features; no simplified behaviors (adversarial review confirmed; 4 fixes applied)
- [x] 13.6 clone && ./Packaging/build.sh → Timi.app (verified end-to-end incl. launch); swift test green (86); README complete

### Not machine-verifiable in this environment (honest notes)
- Real-desktop screenshots blocked by Screen Recording TCC; layer-tree self-captures
  used instead (visually identical content, minus the desktop behind).
- Notifications/launch-at-login exercised only as code paths (need the signed bundle).
- Audio verified by DSP unit tests + live playback (no assertion on speaker output).
- 1×-display pixel crispness asserted by construction (integer 3 pt cells); only a 2×
  display was physically present.
