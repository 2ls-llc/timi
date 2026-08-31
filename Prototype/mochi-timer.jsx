import React, { useRef, useState, useEffect } from "react";
import { Play, Pause, RotateCcw, Volume2, VolumeX } from "lucide-react";

/*
  MOCHI — character 02 for the pixel-pal timer (pip is character 01).
  A little cat on an amber phosphor screen. Same engine, cat soul:
  · a real tail: 4-segment chain physics — sways idle, hangs when
    carried, whips and PUFFS in the final seconds, curls in sleep
  · ears with states: perked when you arrive, flat when stressed,
    drooped when you abandon a session
  · pat = a cat slow-blink (half, closed, half) + purring + blush;
    while happy and idle, mochi kneads
  · deep focus = a proper cat nap, curled in a ball, tail wrapped
  · the last seconds are a hunt: crouch, locked wide eyes, butt
    wiggle... and at 0:00 mochi POUNCES into the confetti, gets the
    zoomies, then settles into a satisfied loaf. banner says NYA
  · meows on start, trills at milestones, hisses if thrown too hard
*/

/* ---------- helpers ---------- */
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;
const TAU = Math.PI * 2;

const fmt = (ms) => {
    const t = Math.max(0, Math.ceil(ms / 1000));
    return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
};

/* amber CRT palette */
const CREAM = "#ffe2b0";
const CREAM_DIM = "#8a7048";
const SLOT = "#2e2519";
const AMBER = "#ffc86e";
const RED = "#ff7a76";
const PINK = "#ff8ba4";
const CYAN = "#9fd8ef";
const TXT = "#e6b377";
const EYE = "#120e08";
const SHADOW = "#080604";

/* 3x5 pixel font */
const FONT = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", "###", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", "..#", "..#", "..#"],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    ":": [".", "#", ".", "#", "."],
    "N": ["#.#", "###", "#.#", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "!": ["#", "#", "#", ".", "#"],
};

/* body variants (13 wide). face row = row of the eyes within each */
const STAND = [
    ".###########.",
    "#############",
    "#############",
    "#############",
    "#############",
    "#############",
    ".###########.",
];
const TALL = [
    ".###########.",
    "#############",
    "#############",
    "#############",
    "#############",
    "#############",
    "#############",
    ".###########.",
];
const LOAF = [
    ".###########.",
    "#############",
    "#############",
    "#############",
    "#############",
    "#############",
];
const CURL = [
    "..#########..",
    ".###########.",
    "#############",
    "#############",
    "#############",
    ".###########.",
    "..#########..",
];
const SQUASH = [
    ".###########.",
    "#############",
    "#############",
    "#############",
    ".###########.",
];
const FEET_A = "..##.....##..";
const FEET_B = "...##...##...";
const DANGLE_A = "....#...#....";
const DANGLE_B = "...#.....#...";
const HEART = [".#.#.", "#####", ".###.", "..#.."];
const MINI_HEART = ["#.#", "###", ".#."];
const ZGLYPH = ["###", ".#.", "###"];

/* ---------- chiptune + cat voice ---------- */
function makeAudio() {
    let ctx = null, master = null, muted = false, noiseBuf = null;
    const ensure = () => {
        if (!ctx) {
            const AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) return;
            ctx = new AC();
            master = ctx.createGain();
            master.gain.value = muted ? 0 : 0.5;
            const lp = ctx.createBiquadFilter();
            lp.type = "lowpass"; lp.frequency.value = 7500;
            master.connect(lp); lp.connect(ctx.destination);
            noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 0.2, ctx.sampleRate);
            const ch = noiseBuf.getChannelData(0);
            for (let i = 0; i < ch.length; i++) ch[i] = Math.random() * 2 - 1;
        }
        if (ctx.state === "suspended") ctx.resume();
    };
    const sq = (freq, dur, vol, when = 0, type = "square") => {
        if (!ctx || muted) return;
        const t0 = ctx.currentTime + when;
        const o = ctx.createOscillator(); const g = ctx.createGain();
        o.type = type; o.frequency.value = freq;
        o.connect(g); g.connect(master);
        g.gain.setValueAtTime(0.0001, t0);
        g.gain.linearRampToValueAtTime(vol, t0 + 0.004);
        g.gain.setValueAtTime(vol, t0 + dur * 0.6);
        g.gain.linearRampToValueAtTime(0.0001, t0 + dur);
        o.start(t0); o.stop(t0 + dur + 0.02);
    };
    const bend = (f0, f1, dur, vol, type = "square", vib = 0) => {
        if (!ctx || muted) return;
        const t0 = ctx.currentTime;
        const o = ctx.createOscillator(); const g = ctx.createGain();
        o.type = type;
        o.frequency.setValueAtTime(f0, t0);
        o.frequency.exponentialRampToValueAtTime(f1, t0 + dur);
        if (vib) {
            const lfo = ctx.createOscillator(); const lg = ctx.createGain();
            lfo.frequency.value = 9; lg.gain.value = vib;
            lfo.connect(lg); lg.connect(o.frequency);
            lfo.start(t0); lfo.stop(t0 + dur + 0.05);
        }
        o.connect(g); g.connect(master);
        g.gain.setValueAtTime(0.0001, t0);
        g.gain.linearRampToValueAtTime(vol, t0 + 0.012);
        g.gain.linearRampToValueAtTime(0.0001, t0 + dur);
        o.start(t0); o.stop(t0 + dur + 0.03);
    };
    const tick = (pitch = 1, vol = 1) => { if (vol > 0.01) sq(1250 * pitch, 0.018, 0.028 * vol); };
    const meow = () => bend(760, 480, 0.22, 0.05, "square", 14);
    const mew = () => bend(880, 1150, 0.14, 0.045, "square", 8);
    const trill = () => { sq(880, 0.035, 0.045); sq(1046, 0.035, 0.045, 0.045); sq(880, 0.035, 0.045, 0.09); sq(1174, 0.05, 0.045, 0.14); };
    const mrrp = () => bend(320, 250, 0.18, 0.04, "triangle", 4);
    const buzz = () => { sq(196, 0.12, 0.05); sq(98, 0.12, 0.03, 0.005, "triangle"); };
    const purr = () => {
        if (!ctx || muted) return;
        const t0 = ctx.currentTime;
        const o = ctx.createOscillator(); const g = ctx.createGain();
        const lfo = ctx.createOscillator(); const lg = ctx.createGain();
        o.type = "triangle"; o.frequency.value = 52;
        lfo.type = "sine"; lfo.frequency.value = 23;
        lg.gain.value = 0.02;
        g.gain.value = 0.022;
        lfo.connect(lg); lg.connect(g.gain);
        o.connect(g); g.connect(master);
        o.start(t0); lfo.start(t0);
        g.gain.setValueAtTime(0.022, t0 + 1.0);
        g.gain.linearRampToValueAtTime(0.0001, t0 + 1.4);
        o.stop(t0 + 1.45); lfo.stop(t0 + 1.45);
    };
    const hiss = (i = 0.6) => {
        if (!ctx || muted) return;
        const t0 = ctx.currentTime;
        const src = ctx.createBufferSource(); src.buffer = noiseBuf;
        const hp = ctx.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 2600;
        const g = ctx.createGain();
        src.connect(hp); hp.connect(g); g.connect(master);
        g.gain.setValueAtTime(0.05 * i, t0);
        g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.16);
        src.start(t0); src.stop(t0 + 0.2);
    };
    const boing = (i = 0.5) => bend(420 + 200 * i, 150, 0.09, 0.05 * i + 0.015);
    const thud = () => sq(180, 0.035, 0.022, 0, "triangle");
    const blip = () => sq(880, 0.03, 0.04);
    const sleepy = () => { sq(392, 0.09, 0.03, 0, "triangle"); sq(261.63, 0.12, 0.03, 0.11, "triangle"); };
    const fanfare = () => {
        [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
            sq(f, 0.07, 0.05, i * 0.08);
            sq(f / 2, 0.07, 0.025, i * 0.08, "triangle");
        });
        [523.25, 659.25, 783.99].forEach((f) => sq(f, 0.28, 0.035, 0.36));
    };
    const setMuted = (m) => { muted = m; if (master) master.gain.value = m ? 0 : 0.5; };
    return { ensure, tick, meow, mew, trill, mrrp, buzz, purr, hiss, boing, thud, blip, sleepy, fanfare, setMuted };
}

/* ---------- css ---------- */
const CSS = `
.mochi-stage { height: 100vh; height: 100dvh; }
.mochi-fade { transition: opacity .3s ease; }
@keyframes mochiRoll {
  from { transform: translateY(-90px); }
  to   { transform: translateY(110vh); }
}
.mochi-btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 5px;
  border: 1px solid rgba(255,226,176,.25);
  background: rgba(255,226,176,.05);
  color: rgba(255,226,176,.75);
  border-radius: 3px; padding: 5px 11px;
  font-size: 11px; font-weight: 600; letter-spacing: .12em;
  cursor: pointer; user-select: none; -webkit-user-select: none;
  transition: background .15s ease, color .15s ease;
  white-space: nowrap; text-transform: uppercase;
  font-family: ui-monospace, 'SF Mono', Menlo, monospace;
}
.mochi-btn:hover { background: rgba(255,226,176,.14); color: #fff3dd; }
.mochi-btn:focus-visible { outline: 1.5px solid rgba(255,226,176,.6); outline-offset: 2px; }
.mochi-btn.on { background: #ffe2b0; color: #16120c; border-color: #ffe2b0; }
.mochi-btn.icon { padding: 5px; width: 26px; height: 26px; }
@media (prefers-reduced-motion: reduce) {
  .mochi-anim * { animation-duration: .01s !important; }
}
`;

/* ---------- component ---------- */
export default function MochiTimer() {
    const [mode, setMode] = useState("idle");
    const [durationMs, setDurationMs] = useState(25 * 60000);
    const [muted, setMuted] = useState(false);
    const [hovered, setHovered] = useState(false);
    const [coarse] = useState(
        () => typeof window !== "undefined" &&
            window.matchMedia && window.matchMedia("(pointer: coarse)").matches
    );

    const containerRef = useRef(null);
    const wrapperRef = useRef(null);
    const canvasRef = useRef(null);
    const glowRef = useRef(null);

    const audioRef = useRef(null);
    if (!audioRef.current) audioRef.current = makeAudio();

    const S = useRef({
        mode: "idle",
        durationMs: 25 * 60000,
        remainingMs: 25 * 60000,
        endAt: 0, fired: {}, lastSec: null,
        pos: { x: 0, y: 0 }, vel: { x: 0, y: 0 }, home: { x: 0, y: 0 },
        dragging: false, dragPointer: { x: 0, y: 0 }, dragOffset: { x: 0, y: 0 }, moved: 0,
        scale: 1, scaleVel: 0,
        hovered: false,
        phase: 0,
        blinkT: -1e9, nextBlink: Infinity, winking: false,
        nextGlance: Infinity, glance: { x: 0, y: 0 }, glanceUntil: 0,
        pointer: { x: 0, y: 0 }, pointerActive: false,
        gaze: { x: 0, y: 0 },
        nextFidget: Infinity, stretchT: -1e9,
        freeFlight: false,
        settle: 0, lastInteract: 0, wakeUntil: 0,
        sleeping: false, wakeFlash: -1e9,
        hearts: 0,
        conf: [], zs: [], miniHearts: [],
        lastZ: 0,
        flashT: -1e9,
        hopY: 0, hopV: 0, prevHopY: 0, landT: -1e9,
        tail: [-1.9, -1.9, -1.9, -1.9],
        doneT: -1e9, prevSegs: -1, segPopT: -1e9, segPopI: -1,
        noticeT: -1e9, prevHovered: false,
        pressT: 0, patT: -1e9,
        flyHeart: null, happyUntil: -1e9, sadUntil: -1e9,
        lastPurr: -1e9,
        g: null,
        reduceMotion: false,
        size: { w: 800, h: 600 },
    }).current;

    S.mode = mode;
    S.hovered = hovered;

    const timeouts = useRef([]);
    const later = (fn, ms) => timeouts.current.push(setTimeout(fn, ms));

    /* --- actions --- */
    const start = () => {
        audioRef.current.ensure();
        S.remainingMs = S.durationMs;
        S.endAt = Date.now() + S.durationMs;
        S.fired = {};
        S.lastSec = Math.ceil(S.durationMs / 1000);
        if (!S.reduceMotion) { S.scale = 0.8; S.hopV = -30; }
        S.wakeUntil = performance.now() + 3000;
        setMode("running");
        audioRef.current.meow();
    };
    const pause = () => {
        S.remainingMs = Math.max(0, S.endAt - Date.now());
        setMode("paused");
        audioRef.current.sleepy();
    };
    const resume = () => {
        audioRef.current.ensure();
        S.endAt = Date.now() + S.remainingMs;
        setMode("running");
        audioRef.current.mew();
    };
    const reset = () => {
        if (S.mode === "running" || S.mode === "paused") {
            const rem = S.mode === "running" ? Math.max(0, S.endAt - Date.now()) : S.remainingMs;
            if (S.durationMs - rem > 15000) {
                S.sadUntil = performance.now() + 5000;
                audioRef.current.mrrp();
            }
        }
        S.remainingMs = S.durationMs;
        S.fired = {};
        setMode("idle");
    };
    const finish = () => {
        S.remainingMs = 0;
        S.freeFlight = false;
        setMode("done");
        S.flyHeart = { x: 28, y: 18, t0: performance.now() + 1100 };
        S.happyUntil = performance.now() + 10000;
        S.doneT = performance.now();
        audioRef.current.fanfare();
        later(() => audioRef.current.mew(), 700);
        const wave = (n) => {
            for (let i = 0; i < n; i++) {
                S.conf.push({
                    x: 28 + (Math.random() - 0.5) * 10,
                    y: 22,
                    vx: (Math.random() - 0.5) * 40,
                    vy: -30 - Math.random() * 45,
                    c: [CREAM, AMBER, PINK, CYAN, "#ffffff"][i % 5],
                    life: 1.4 + Math.random() * 0.5,
                });
            }
        };
        if (!S.reduceMotion) {
            // the pounce
            S.hopV = -50;
            S.vel.x += (S.pos.x < S.size.w / 2 ? 1 : -1) * 260;
            wave(28);
            later(() => wave(16), 600);
        }
        S.home = { x: S.size.w / 2, y: S.size.h / 2 - 20 };
        later(() => { if (S.mode === "done") reset(); }, 6400);
    };
    const tap = () => {
        if (S.mode === "idle") start();
        else if (S.mode === "running") pause();
        else if (S.mode === "paused") resume();
        else reset();
    };
    const apiRef = useRef({});
    apiRef.current = { tap, reset, finish, start };

    const toggleMute = () => {
        setMuted((m) => {
            audioRef.current.setMuted(!m);
            return !m;
        });
    };

    const pickDuration = (ms) => {
        audioRef.current.ensure();
        setDurationMs(ms);
        S.durationMs = ms;
        S.remainingMs = ms;
        audioRef.current.blip();
    };

    /* --- mount --- */
    useEffect(() => {
        const el = containerRef.current;
        const measure = () => {
            const r = el.getBoundingClientRect();
            S.size = { w: r.width, h: r.height };
            S.home.x = clamp(S.home.x, 90, r.width - 90);
            S.home.y = clamp(S.home.y, 90, r.height - 90);
        };
        measure();
        S.home = { x: S.size.w * 0.5, y: S.size.h * 0.45 };
        S.pos = { ...S.home };
        const now0 = performance.now();
        S.nextFidget = now0 + 6000;
        S.nextBlink = now0 + 2400;
        S.nextGlance = now0 + 4000;
        S.lastInteract = now0;
        if (window.matchMedia)
            S.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        S.g = canvasRef.current.getContext("2d");
        const ro = new ResizeObserver(measure);
        ro.observe(el);

        const onKey = (e) => {
            S.lastInteract = performance.now();
            if (e.code === "Space") { e.preventDefault(); audioRef.current.ensure(); apiRef.current.tap(); }
            else if (e.key === "r" || e.key === "R") apiRef.current.reset();
            else if (e.key === "m" || e.key === "M") toggleMute();
        };
        window.addEventListener("keydown", onKey);

        const wrap = wrapperRef.current;
        const onWheel = (e) => {
            if (S.mode !== "idle") return;
            e.preventDefault();
            const step = e.deltaY > 0 ? -60000 : 60000;
            const next = clamp(S.durationMs + step, 60000, 90 * 60000);
            if (next !== S.durationMs) {
                S.durationMs = next;
                S.remainingMs = next;
                setDurationMs(next);
                audioRef.current.ensure();
                audioRef.current.blip();
            }
        };
        wrap.addEventListener("wheel", onWheel, { passive: false });

        const onMove = (e) => {
            if (e.pointerType && e.pointerType !== "mouse") return;
            const r = el.getBoundingClientRect();
            S.pointer = { x: e.clientX - r.left, y: e.clientY - r.top };
            S.pointerActive = true;
            S.lastInteract = performance.now();
        };
        const onLeave = () => { S.pointerActive = false; };
        el.addEventListener("pointermove", onMove);
        el.addEventListener("pointerleave", onLeave);

        const px = (g, x, y, c, w = 1, h = 1) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
        const sprite = (g, rows, x0, y0, c) => {
            for (let r = 0; r < rows.length; r++)
                for (let cc = 0; cc < rows[r].length; cc++)
                    if (rows[r][cc] === "#") px(g, x0 + cc, y0 + r, c);
        };
        const spriteLean = (g, rows, x0, y0, c, lean) => {
            for (let r = 0; r < rows.length; r++) {
                const off = r < rows.length / 2 ? lean : 0;
                for (let cc = 0; cc < rows[r].length; cc++)
                    if (rows[r][cc] === "#") px(g, x0 + cc + off, y0 + r, c);
            }
        };
        const textW = (s) => {
            let w = 0;
            for (const ch of s) w += (FONT[ch] ? FONT[ch][0].length : 3) + 1;
            return w - 1;
        };
        const drawText = (g, s, x0, y0, c, colonOn = true) => {
            let x = x0;
            for (const ch of s) {
                const gl = FONT[ch];
                if (gl) {
                    if (ch !== ":" || colonOn) sprite(g, gl, x, y0, c);
                    x += gl[0].length + 1;
                }
                else x += 4;
            }
        };

        /* ----- the loop ----- */
        let raf, last = performance.now();
        const loop = (t) => {
            const dt = clamp((t - last) / 1000, 0, 0.05);
            last = t;
            const rm = S.reduceMotion;

            if (S.mode === "running") {
                S.remainingMs = S.endAt - Date.now();
                if (S.remainingMs <= 0) {
                    S.remainingMs = 0;
                    apiRef.current.finish();
                } else {
                    const sec = Math.ceil(S.remainingMs / 1000);
                    if (sec !== S.lastSec) {
                        S.lastSec = sec;
                        const elapsed = (S.durationMs - S.remainingMs) / 1000;
                        const rem = S.remainingMs / 1000;
                        let vol = 0, pitch = 1;
                        if (rem <= 10.5) { vol = 1; pitch = 1 + (10 - rem) * 0.03; }
                        else if (rem <= 60) vol = clamp((60 - rem) / 5, 0, 1);
                        else if (elapsed < 20) vol = 1;
                        else if (elapsed < 45) vol = 1 - (elapsed - 20) / 25;
                        audioRef.current.tick(pitch, vol);
                    }
                    const dms = S.durationMs, rms = S.remainingMs;
                    if (dms >= 30000 && rms <= dms * 0.5 && !S.fired.half) {
                        S.fired.half = true;
                        audioRef.current.trill();
                        S.flashT = t; S.wakeUntil = t + 2600;
                        if (!rm) S.hopV = -34;
                    }
                    if (dms >= 240000 && rms <= dms * 0.25 && !S.fired.quarter) {
                        S.fired.quarter = true;
                        audioRef.current.trill();
                        S.flashT = t; S.wakeUntil = t + 2600;
                        if (!rm) S.hopV = -34;
                    }
                    if (dms > 150000 && rms <= 60000 && !S.fired.minute) {
                        S.fired.minute = true;
                        audioRef.current.buzz();
                        S.flashT = t; S.wakeUntil = t + 2600;
                    }
                }
            }

            const p = S.mode === "idle" ? 0
                : S.mode === "done" ? 1
                    : clamp(1 - S.remainingMs / S.durationMs, 0, 1);
            const remS = S.remainingMs / 1000;
            const running = S.mode === "running";
            const panic = running && remS <= 10;      // the hunt
            const wiggle = running && remS <= 3.5;    // pre-pounce butt wiggle
            const zoomies = S.mode === "done" && t - S.doneT > 900 && t - S.doneT < 3200 && !rm;

            /* settle -> cat nap */
            const settleTarget =
                running && !S.hovered && !S.dragging && !S.freeFlight &&
                    t > S.wakeUntil && t - S.lastInteract > 10000 && remS > 75 ? 1 : 0;
            S.settle += (settleTarget - S.settle) *
                Math.min(1, dt * (settleTarget > S.settle ? 0.35 : 2.8));
            const sleeping = S.settle > 0.6;
            if (sleeping !== S.sleeping) {
                S.sleeping = sleeping;
                if (sleeping) audioRef.current.sleepy();
                else { audioRef.current.mew(); S.wakeFlash = t; S.stretchT = t; }
            }
            const bored = S.mode === "idle" && t - S.lastInteract > 30000;
            const purring = t - S.patT < 1500;
            const happy = t < S.happyUntil && !panic && !sleeping;
            if (purring && t - S.lastPurr > 1450) { S.lastPurr = t; audioRef.current.purr(); }

            /* breath */
            let period =
                S.mode === "paused" ? 5.5 :
                    S.mode === "idle" ? 3.2 :
                        S.mode === "done" ? 1.0 :
                            lerp(3.2, 1.0, p * p);
            if (panic) period = 0.5;
            period *= 1 + 0.8 * S.settle;
            S.phase += (TAU * dt) / period;

            /* blink / wink */
            if (t > S.nextBlink && !sleeping && !rm && !panic) {
                S.blinkT = t;
                S.winking = Math.random() < 0.25;
                S.nextBlink = Math.random() < 0.2 ? t + 300 : t + 2800 + Math.random() * 5000;
            }
            const blinking = t - S.blinkT < 140;

            /* fidgets: stroll, hop, glance, big stretch, ear twitch */
            if (S.mode === "idle" && !S.dragging && !rm && !bored && t > S.nextFidget) {
                const r = Math.random();
                if (r < 0.3) {
                    S.home.x = clamp(
                        S.home.x + (Math.random() < 0.5 ? -1 : 1) * (50 + Math.random() * 45),
                        90, S.size.w - 90);
                }
                else if (r < 0.5) S.hopV = -32;
                else if (r < 0.7) { S.glance = { x: (Math.random() - 0.5) * 8, y: 0 }; S.glanceUntil = t + 900; }
                else if (r < 0.9) S.stretchT = t;
                else S.noticeT = t; // ear twitch
                S.nextFidget = t + 8000 + Math.random() * 9000;
            }
            if (S.mode !== "idle") S.nextFidget = t + 7000;
            const stretching = t - S.stretchT < 650;

            /* hop physics */
            S.prevHopY = S.hopY;
            S.hopV += 260 * dt;
            S.hopY += S.hopV * dt;
            if (S.hopY >= 0) {
                if (S.prevHopY < -0.6 && !rm) { S.landT = t; audioRef.current.thud(); }
                S.hopY = 0; S.hopV = 0;
            }
            const landing = t - S.landT < 100;

            /* zoomies drive the home target back and forth */
            if (zoomies) {
                S.home.x = S.size.w / 2 + Math.sin((t - S.doneT - 900) / 135) * Math.min(80, S.size.w * 0.18);
            }

            /* motion */
            if (S.freeFlight && !S.dragging) {
                const drg = Math.exp(-1.5 * dt);
                S.vel.x *= drg; S.vel.y *= drg;
                S.pos.x += S.vel.x * dt;
                S.pos.y += S.vel.y * dt;
                const R = 78;
                let hit = 0;
                if (S.pos.x < R) { S.pos.x = R; S.vel.x = Math.abs(S.vel.x) * 0.72; hit = 1; }
                else if (S.pos.x > S.size.w - R) { S.pos.x = S.size.w - R; S.vel.x = -Math.abs(S.vel.x) * 0.72; hit = 1; }
                if (S.pos.y < R) { S.pos.y = R; S.vel.y = Math.abs(S.vel.y) * 0.72; hit = 1; }
                else if (S.pos.y > S.size.h - R) { S.pos.y = S.size.h - R; S.vel.y = -Math.abs(S.vel.y) * 0.72; hit = 1; }
                if (hit) {
                    const imp = clamp(Math.hypot(S.vel.x, S.vel.y) / 1400, 0.2, 1);
                    S.scale = Math.min(S.scale, 1 - 0.18 * imp);
                    S.lastInteract = t;
                    audioRef.current.boing(imp);
                    if (imp > 0.55) audioRef.current.hiss(imp);
                }
                if (Math.hypot(S.vel.x, S.vel.y) < 140) {
                    S.freeFlight = false;
                    S.home = {
                        x: clamp(S.pos.x, 90, S.size.w - 90),
                        y: clamp(S.pos.y, 90, S.size.h - 90),
                    };
                }
            } else {
                const target = S.dragging
                    ? { x: S.dragPointer.x - S.dragOffset.x, y: S.dragPointer.y - S.dragOffset.y }
                    : S.home;
                const stiff = S.dragging ? 380 : zoomies ? 200 : 90;
                const damp = S.dragging ? 26 : zoomies ? 16 : 11;
                S.vel.x += (target.x - S.pos.x) * stiff * dt;
                S.vel.y += (target.y - S.pos.y) * stiff * dt;
                const dk = Math.exp(-damp * dt);
                S.vel.x *= dk; S.vel.y *= dk;
                S.pos.x += S.vel.x * dt;
                S.pos.y += S.vel.y * dt;
            }

            const targetScale = S.hovered && S.mode !== "done" ? 1.06 : 1;
            S.scaleVel += (targetScale - S.scale) * 240 * dt;
            S.scaleVel *= Math.exp(-13 * dt);
            S.scale += S.scaleVel * dt;

            const speed = Math.hypot(S.vel.x, S.vel.y);
            const st = clamp(speed * 0.0004, 0, 0.16) * (rm ? 0.3 : 1);
            const walking = speed > 90 && !S.dragging && !S.freeFlight;
            const airborne = S.dragging || S.freeFlight;

            /* notice */
            if (S.hovered !== S.prevHovered) {
                S.prevHovered = S.hovered;
                if (S.hovered) S.noticeT = t;
            }
            const noticing = t - S.noticeT < 600;

            /* gaze */
            let gx = 0, gy = 0;
            let near = false;
            if (S.pointerActive && !S.dragging) {
                const dx = S.pointer.x - S.pos.x, dy = S.pointer.y - S.pos.y;
                const d = Math.hypot(dx, dy) || 1;
                if (d < 300) { near = true; gx = (dx / d) * 4; gy = (dy / d) * 4; }
            }
            if (!near && t < S.glanceUntil) { gx = S.glance.x; gy = S.glance.y; }
            S.gaze.x += (gx - S.gaze.x) * Math.min(1, dt * 6);
            S.gaze.y += (gy - S.gaze.y) * Math.min(1, dt * 6);

            /* tail chain physics */
            let tailBase;
            if (S.dragging || S.freeFlight) tailBase = 1.35;                        // hangs
            else if (sleeping) tailBase = -2.6;
            else if (panic) tailBase = -1.6 + Math.sin(t / 45) * 0.9;               // whipping
            else if (purring || happy) tailBase = -1.9 + Math.sin(t / 420) * 0.5;   // content sway
            else tailBase = -1.9 + Math.sin(t / 640) * 0.35
                + clamp(-S.vel.x * 0.0016, -0.5, 0.5);
            S.tail[0] += (tailBase - S.tail[0]) * Math.min(1, dt * 8);
            for (let i = 1; i < 4; i++)
                S.tail[i] += (S.tail[i - 1] - S.tail[i]) * Math.min(1, dt * (7 - i * 1.2));

            /* particles */
            if (sleeping && t - S.lastZ > 1700 && !rm) {
                S.lastZ = t;
                S.zs.push({ x: 38, y: 14, life: 1.8 });
            }
            S.conf.forEach((c) => { c.vy += 65 * dt; c.x += c.vx * dt; c.y += c.vy * dt; c.life -= dt; });
            S.conf = S.conf.filter((c) => c.life > 0 && c.y < 47);
            S.zs.forEach((z) => { z.y -= 3.5 * dt; z.life -= dt; });
            S.zs = S.zs.filter((z) => z.life > 0);
            S.miniHearts.forEach((h) => { h.y += h.vy * dt; h.life -= dt; });
            S.miniHearts = S.miniHearts.filter((h) => h.life > 0);

            /* ---- CSS writes ---- */
            let sxc = 1, syc = 1;
            if (Math.abs(S.vel.x) > Math.abs(S.vel.y)) { sxc = 1 + st; syc = 1 - st * 0.6; }
            else { syc = 1 + st; sxc = 1 - st * 0.6; }
            wrapperRef.current.style.transform =
                `translate3d(${S.pos.x.toFixed(1)}px, ${S.pos.y.toFixed(1)}px, 0)`;
            canvasRef.current.style.transform =
                `translate(-50%,-50%) scale(${(sxc * S.scale).toFixed(3)}, ${(syc * S.scale).toFixed(3)})`;
            canvasRef.current.style.opacity = sleeping ? "0.88" : "1";
            const gb = 0.5 + 0.5 * Math.sin(S.phase);
            glowRef.current.style.opacity = ((0.35 + 0.3 * gb) * (sleeping ? 0.45 : 1)).toFixed(2);

            /* ---- pixel draw ---- */
            const g = S.g;
            g.clearRect(0, 0, 56, 48);

            const nH = Math.min(S.hearts, 8);
            for (let i = 0; i < nH; i++) sprite(g, HEART, 2 + i * 6, 2, PINK);
            if (S.flyHeart && t >= S.flyHeart.t0) {
                const k = clamp((t - S.flyHeart.t0) / 900, 0, 1);
                const slot = Math.min(S.hearts, 7);
                const ex = lerp(S.flyHeart.x, 3 + slot * 6, k);
                const ey = lerp(S.flyHeart.y, 3, k) - Math.sin(k * Math.PI) * 7;
                sprite(g, MINI_HEART, Math.round(ex) - 1, Math.round(ey) - 1, PINK);
                if (k >= 1) { S.flyHeart = null; S.hearts += 1; audioRef.current.blip(); }
            }
            S.miniHearts.forEach((h) =>
                sprite(g, MINI_HEART, Math.round(h.x) - 1, Math.round(h.y) - 1, PINK));

            const labelVisible =
                S.mode === "idle" || S.mode === "paused" ||
                S.hovered || (running && S.remainingMs <= 61000);
            if (labelVisible && S.mode !== "done") {
                const s = fmt(S.mode === "idle" ? S.durationMs : S.remainingMs);
                const colonOn = !running || Math.floor(t / 500) % 2 === 0;
                drawText(g, s, Math.round(28 - textW(s) / 2), 2,
                    panic ? (Math.floor(t / 250) % 2 ? RED : TXT) : TXT, colonOn);
            }
            if (S.mode === "done" && t - S.doneT < 2200) {
                drawText(g, "NYA!", Math.round(28 - textW("NYA!") / 2), 2,
                    Math.floor(t / 180) % 2 ? AMBER : "#ffffff");
            }

            const frac = S.mode === "idle" ? 1 : clamp(S.remainingMs / S.durationMs, 0, 1);
            const segs = Math.ceil(frac * 20);
            if (segs < S.prevSegs && running) { S.segPopT = t; S.segPopI = segs; }
            S.prevSegs = segs;
            let barC = CREAM;
            if (running && remS <= 60) barC = AMBER;
            if (panic) barC = Math.floor(t / 250) % 2 ? RED : AMBER;
            for (let i = 0; i < 20; i++) {
                const popping = i === S.segPopI && t - S.segPopT < 130;
                px(g, 8 + i * 2, 41, popping ? "#fff3dd" : i < segs ? barC : SLOT, 1, 3);
            }

            /* ---- the cat ---- */
            const squashing = landing || S.scale < 0.92;
            const loaf = (bored || (S.mode === "done" && t - S.doneT >= 3200)) && !squashing;
            const crouch = panic && !airborne;
            const bounce = sleeping || loaf ? 0 : Math.round(Math.sin(S.phase) * (panic ? 0.6 : 1.1));
            const wig = wiggle && !rm ? (Math.floor(t / 80) % 2 ? 1 : -1) : 0;
            const lift = Math.round(S.hopY);
            const bx = 21 + wig;
            let body, faceRow, bodyY;
            if (sleeping) { body = CURL; faceRow = 3; bodyY = 22; }
            else if (loaf) { body = LOAF; faceRow = 2; bodyY = 22; }
            else if (stretching) { body = TALL; faceRow = 4; bodyY = 19 + bounce + lift; }
            else if (squashing || crouch) { body = SQUASH; faceRow = 2; bodyY = 23 + bounce + lift; }
            else { body = STAND; faceRow = 3; bodyY = 21 + bounce + lift; }
            const by = bodyY;
            const bodyH = body.length;

            /* ground shadow */
            if (!airborne) {
                const h = Math.min(4, Math.abs(lift) + Math.max(0, -bounce));
                const w = 9 - h;
                px(g, 28 - Math.floor(w / 2), 31, SHADOW, w, 1);
            }

            /* tail (behind body) */
            if (!sleeping) {
                let txp = bx + 12.5, typ = by + Math.min(5, bodyH - 2);
                const puff = panic && !rm;
                for (let i = 0; i < 4; i++) {
                    txp += Math.cos(S.tail[i]) * 2.3;
                    typ += Math.sin(S.tail[i]) * 2.3;
                    const cx2 = Math.round(txp), cy2 = Math.round(typ);
                    px(g, cx2, cy2, i === 3 ? "#fff0d0" : CREAM);
                    if (puff) { px(g, cx2 + 1, cy2, CREAM_DIM); px(g, cx2, cy2 + 1, CREAM_DIM); }
                }
            } else {
                // curled tail across the front
                px(g, bx + 2, by + bodyH - 2, CREAM_DIM, 8, 1);
            }

            /* body */
            const lean = walking ? (S.vel.x > 0 ? 1 : -1) : 0;
            if (lean) spriteLean(g, body, bx, by, CREAM, lean);
            else sprite(g, body, bx, by, CREAM);
            px(g, bx + 1, by + bodyH - 1, CREAM_DIM, 11, 1);

            /* ears */
            const earsFlat = panic || t < S.sadUntil || (airborne && speed > 420);
            if (!sleeping) {
                if (earsFlat) {
                    px(g, bx, by + 1, CREAM, 2, 1); px(g, bx + 11, by + 1, CREAM, 2, 1);
                } else {
                    const perk = noticing ? 1 : 0;
                    px(g, bx + 1, by - 1 - perk, CREAM); px(g, bx + 1, by - 2 - perk, CREAM);
                    px(g, bx + 2, by - 1 - perk, CREAM);
                    px(g, bx + 11, by - 1 - perk, CREAM); px(g, bx + 11, by - 2 - perk, CREAM);
                    px(g, bx + 10, by - 1 - perk, CREAM);
                    px(g, bx + 1, by - 1 - perk, PINK); px(g, bx + 11, by - 1 - perk, PINK);
                }
            } else {
                px(g, bx + 2, by - 1, CREAM); px(g, bx + 10, by - 1, CREAM);
            }

            /* feet */
            if (!sleeping && !loaf && !squashing && !crouch) {
                let feet;
                if (airborne) feet = Math.floor(t / 260) % 2 ? DANGLE_A : DANGLE_B;
                else if (happy && !walking && S.mode === "idle")
                    feet = Math.floor(t / 300) % 2 ? FEET_A : FEET_B;   // kneading
                else feet = walking ? (Math.floor(t / 130) % 2 ? FEET_A : FEET_B) : FEET_A;
                sprite(g, [feet], bx, by + bodyH, CREAM);
            }

            /* landing dust */
            if (landing && !rm) {
                px(g, bx - 1, by + bodyH, CREAM_DIM);
                px(g, bx + 13, by + bodyH, CREAM_DIM);
            }

            /* face */
            const er = by + faceRow;
            const eox = clamp(Math.round(S.gaze.x / 2.4), -1, 1);
            const eoy = S.dragging ? 1 : clamp(Math.round(S.gaze.y / 3), -1, 1);
            const worried = S.freeFlight || (S.dragging && speed > 420);
            const patAge = t - S.patT;
            // whiskers
            if (!sleeping) {
                px(g, bx - 2, er + 1, CREAM_DIM, 2, 1);
                px(g, bx + 13, er + 1, CREAM_DIM, 2, 1);
            }
            // nose + mouth
            if (!sleeping) {
                px(g, bx + 6, er + 2, PINK);
                if (!panic && !worried) { px(g, bx + 5, er + 3, EYE); px(g, bx + 7, er + 3, EYE); }
            }
            if (S.mode === "done" && t - S.doneT < 3200) {
                px(g, bx + 3, er, EYE); px(g, bx + 2, er + 1, EYE); px(g, bx + 4, er + 1, EYE);
                px(g, bx + 9, er, EYE); px(g, bx + 8, er + 1, EYE); px(g, bx + 10, er + 1, EYE);
                px(g, bx + 1, er + 2, PINK); px(g, bx + 11, er + 2, PINK);
            } else if (patAge < 1300) {
                // cat slow-blink: half, closed, half
                if (patAge < 250 || patAge > 800) {
                    px(g, bx + 3, er + 1, EYE); px(g, bx + 9, er + 1, EYE);
                } else {
                    px(g, bx + 3, er + 1, EYE, 2, 1); px(g, bx + 8, er + 1, EYE, 2, 1);
                }
                px(g, bx + 1, er + 2, PINK); px(g, bx + 11, er + 2, PINK);
            } else if (t < S.sadUntil) {
                px(g, bx + 3, er + 1, EYE, 2, 1);
                px(g, bx + 8, er + 1, EYE, 2, 1);
                px(g, bx + 5, er + 3, EYE); px(g, bx + 7, er + 3, EYE);
                px(g, bx + 6, er + 4, EYE);
            } else if (sleeping || S.mode === "paused" || stretching) {
                px(g, bx + 3, er + 1, EYE, 2, 1);
                px(g, bx + 8, er + 1, EYE, 2, 1);
            } else if (blinking) {
                if (S.winking) {
                    px(g, bx + 3, er + 1, EYE, 2, 1);
                    px(g, bx + 9 + eox, er + eoy, EYE, 1, 2);
                } else {
                    px(g, bx + 3, er + 1, EYE, 2, 1);
                    px(g, bx + 8, er + 1, EYE, 2, 1);
                }
            } else if (panic || worried) {
                px(g, bx + 2 + eox, er, EYE, 2, 2);
                px(g, bx + 8 + eox, er, EYE, 2, 2);
            } else if (happy) {
                px(g, bx + 3, er + 1, EYE, 2, 1);
                px(g, bx + 8, er + 1, EYE, 2, 1);
                px(g, bx + 1, er + 2, PINK); px(g, bx + 11, er + 2, PINK);
            } else if (noticing) {
                px(g, bx + 2 + eox, er, EYE, 2, 2);
                px(g, bx + 8 + eox, er, EYE, 2, 2);
            } else {
                px(g, bx + 3 + eox, er + eoy, EYE, 1, 2);
                px(g, bx + 9 + eox, er + eoy, EYE, 1, 2);
            }

            if (t - S.wakeFlash < 450) {
                px(g, bx + 6, by - 8, AMBER, 1, 3);
                px(g, bx + 6, by - 4, AMBER);
            }

            S.zs.forEach((z) => sprite(g, ZGLYPH, Math.round(z.x), Math.round(z.y), CYAN));
            S.conf.forEach((c) => px(g, Math.round(c.x), Math.round(c.y), c.c));

            if (t - S.flashT < 90) {
                g.fillStyle = "rgba(255,226,176,.15)";
                g.fillRect(0, 0, 56, 48);
            }

            raf = requestAnimationFrame(loop);
        };
        raf = requestAnimationFrame(loop);

        return () => {
            cancelAnimationFrame(raf);
            ro.disconnect();
            window.removeEventListener("keydown", onKey);
            wrap.removeEventListener("wheel", onWheel);
            el.removeEventListener("pointermove", onMove);
            el.removeEventListener("pointerleave", onLeave);
            timeouts.current.forEach(clearTimeout);
        };
    }, []); // eslint-disable-line

    const localPoint = (e) => {
        const r = containerRef.current.getBoundingClientRect();
        return { x: e.clientX - r.left, y: e.clientY - r.top };
    };
    const onPointerDown = (e) => {
        if (e.target.closest("button")) return;
        audioRef.current.ensure();
        const pt = localPoint(e);
        S.dragging = true;
        S.freeFlight = false;
        S.moved = 0;
        S.pressT = performance.now();
        S.lastInteract = performance.now();
        S.dragPointer = pt;
        S.dragOffset = { x: pt.x - S.pos.x, y: pt.y - S.pos.y };
        wrapperRef.current.style.cursor = "grabbing";
        e.currentTarget.setPointerCapture(e.pointerId);
    };
    const onPointerMove = (e) => {
        if (!S.dragging) return;
        const pt = localPoint(e);
        S.moved += Math.hypot(pt.x - S.dragPointer.x, pt.y - S.dragPointer.y);
        S.dragPointer = pt;
        S.lastInteract = performance.now();
    };
    const onPointerUp = () => {
        if (!S.dragging) return;
        S.dragging = false;
        wrapperRef.current.style.cursor = "grab";
        if (S.moved < 6) {
            if (performance.now() - S.pressT >= 450) {
                S.patT = performance.now();
                S.miniHearts.push({ x: 24 + Math.random() * 8, y: 12, vy: -7, life: 1.1 });
            } else {
                apiRef.current.tap();
            }
            return;
        }
        const spd = Math.hypot(S.vel.x, S.vel.y);
        if (spd > 650) {
            const cap = 2600 / Math.max(spd, 1);
            if (cap < 1) { S.vel.x *= cap; S.vel.y *= cap; }
            S.freeFlight = true;
        } else {
            S.home = {
                x: clamp(S.pos.x, 90, S.size.w - 90),
                y: clamp(S.pos.y, 90, S.size.h - 90),
            };
        }
    };

    const presets = [
        { label: "30s", ms: 30000 },
        { label: "5m", ms: 300000 },
        { label: "15m", ms: 900000 },
        { label: "25m", ms: 1500000 },
    ];
    const showControls =
        mode === "idle" || mode === "paused" || (hovered && mode === "running");

    return (
        <div
            ref={containerRef}
            className="mochi-anim mochi-stage"
            style={{
                position: "relative", width: "100%", overflow: "hidden",
                background: "radial-gradient(115% 100% at 50% 40%, #1a140c 0%, #16120c 55%, #0d0a06 100%)",
                fontFamily: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace",
                userSelect: "none", WebkitUserSelect: "none",
            }}
        >
            <style>{CSS}</style>

            <div style={{ position: "absolute", top: 22, left: 26, pointerEvents: "none" }}>
                <div style={{ color: "rgba(255,226,176,.85)", fontSize: 13, fontWeight: 700, letterSpacing: ".22em" }}>
                    MOCHI
                </div>
                <div style={{ color: "rgba(230,179,119,.45)", fontSize: 10.5, marginTop: 3, letterSpacing: ".08em" }}>
                    PIXEL CAT TIMER — CHARACTER 02
                </div>
            </div>

            <div style={{
                position: "absolute", bottom: 20, left: 0, right: 0,
                textAlign: "center", pointerEvents: "none",
                color: "rgba(230,179,119,.4)", fontSize: 10.5, letterSpacing: ".1em",
                padding: "0 16px", textTransform: "uppercase",
            }}>
                {coarse
                    ? "tap mochi to start · hold to pat · drag or fling anywhere"
                    : <>tap mochi to start · hold to pat · drag or fling anywhere
                        <span style={{ opacity: 0.7 }}> · scroll = time · space / R / M</span></>}
            </div>

            <div
                ref={wrapperRef}
                aria-label="pixel cat timer"
                onPointerDown={onPointerDown}
                onPointerMove={onPointerMove}
                onPointerUp={onPointerUp}
                onPointerCancel={onPointerUp}
                onPointerEnter={(e) => e.pointerType === "mouse" && setHovered(true)}
                onPointerLeave={(e) => e.pointerType === "mouse" && setHovered(false)}
                style={{
                    position: "absolute", left: 0, top: 0,
                    willChange: "transform", cursor: "grab", touchAction: "none",
                }}
            >
                <div ref={glowRef} style={{
                    position: "absolute", left: 0, top: 0, width: 260, height: 230,
                    transform: "translate(-50%,-50%)", borderRadius: "50%",
                    pointerEvents: "none",
                    background: "radial-gradient(circle, rgba(255,210,140,.14) 0%, rgba(255,210,140,0) 62%)",
                }} />

                <canvas
                    ref={canvasRef}
                    width={56} height={48}
                    style={{
                        position: "absolute", left: 0, top: 0,
                        width: 168, height: 144,
                        transform: "translate(-50%,-50%)",
                        imageRendering: "pixelated",
                        willChange: "transform",
                    }}
                />

                <div className="mochi-fade" style={{
                    position: "absolute", top: 84, left: 0,
                    transform: "translateX(-50%)",
                    display: "flex", gap: 5, alignItems: "center",
                    opacity: showControls ? 1 : 0,
                    pointerEvents: showControls ? "auto" : "none",
                }}>
                    {mode === "idle" ? (
                        <>
                            {presets.map((pr) => (
                                <button key={pr.label}
                                    className={`mochi-btn ${durationMs === pr.ms ? "on" : ""}`}
                                    onClick={() => pickDuration(pr.ms)}
                                    aria-label={`set timer to ${pr.label}`}>
                                    {pr.label}
                                </button>
                            ))}
                            <button className="mochi-btn icon" onClick={toggleMute} title="mute (M)" aria-label="toggle sound">
                                {muted ? <VolumeX size={12} /> : <Volume2 size={12} />}
                            </button>
                        </>
                    ) : (
                        <>
                            <button className="mochi-btn icon"
                                onClick={() => (mode === "running" ? pause() : resume())}
                                title="pause / resume (space)"
                                aria-label={mode === "running" ? "pause timer" : "resume timer"}>
                                {mode === "running" ? <Pause size={12} /> : <Play size={12} />}
                            </button>
                            <button className="mochi-btn icon" onClick={toggleMute} title="mute (M)" aria-label="toggle sound">
                                {muted ? <VolumeX size={12} /> : <Volume2 size={12} />}
                            </button>
                            <button className="mochi-btn icon" onClick={reset} title="reset (R)" aria-label="reset timer">
                                <RotateCcw size={12} />
                            </button>
                        </>
                    )}
                </div>
            </div>

            <div style={{
                position: "absolute", left: 0, right: 0, top: 0, height: 80,
                pointerEvents: "none",
                background: "linear-gradient(rgba(255,255,255,0) 0%, rgba(255,255,255,.028) 50%, rgba(255,255,255,0) 100%)",
                animation: "mochiRoll 7s linear infinite",
            }} />
            <div style={{
                position: "absolute", inset: 0, pointerEvents: "none",
                background: "repeating-linear-gradient(rgba(0,0,0,.16) 0 1px, transparent 1px 3px)",
            }} />
            <div style={{
                position: "absolute", inset: 0, pointerEvents: "none",
                background: "radial-gradient(120% 100% at 50% 45%, rgba(0,0,0,0) 55%, rgba(0,0,0,.5) 100%)",
            }} />
        </div>
    );
}