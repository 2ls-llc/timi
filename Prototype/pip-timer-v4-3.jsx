import React, { useRef, useState, useEffect } from "react";
import { Play, Pause, RotateCcw, Volume2, VolumeX } from "lucide-react";

/*
  pip v4.3 — PERSONALITY PASS (cumulative: includes 4.1 + 4.2)
  · hold pip briefly (no drag) to PAT it — happy squint, blush, a
    little heart floats up. patting never toggles the timer.
  · earned hearts now fly from pip to the collection, arcing across
    the screen before landing in the row.
  · moods: finishing keeps pip visibly happy for a while afterward;
    abandoning a session mid-run earns you a brief guilt-trip frown.
  · pip wanders: left alone while idle it strolls a few steps on its
    own, feet animating.
*/

/* ---------- helpers ---------- */
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;
const TAU = Math.PI * 2;

const fmt = (ms) => {
  const t = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
};

/* palette */
const MINT = "#baf2d0";
const MINT_DIM = "#5f9d80";
const SLOT = "#243029";
const AMBER = "#ffd27a";
const RED = "#ff7a76";
const PINK = "#ff7a9e";
const CYAN = "#8fe3ff";
const TXT = "#8fd8b4";
const EYE = "#0d0f12";
const SHADOW = "#070809";

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
  "A": ["###", "#.#", "###", "#.#", "#.#"],
  "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
};

const BODY = [
  "...#######...",
  "..#########..",
  ".###########.",
  "#############",
  "#############",
  "#############",
  "#############",
  ".###########.",
];
const BODY_SQ = [
  ".###########.",
  "#############",
  "#############",
  "#############",
  "#############",
  ".###########.",
];
const FEET_A = "..##.....##..";
const FEET_B = "...##...##...";
const FEET_SIT = "#############";
const DANGLE_A = "....#...#....";
const DANGLE_B = "...#.....#...";
const HEART = [".#.#.", "#####", ".###.", "..#.."];
const MINI_HEART = ["#.#", "###", ".#."];
const ZGLYPH = ["###", ".#.", "###"];

/* ---------- chiptune ---------- */
function makeAudio() {
  let ctx = null, master = null, muted = false;
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
  const sweep = (f0, f1, dur, vol) => {
    if (!ctx || muted) return;
    const t0 = ctx.currentTime;
    const o = ctx.createOscillator(); const g = ctx.createGain();
    o.type = "square";
    o.frequency.setValueAtTime(f0, t0);
    o.frequency.exponentialRampToValueAtTime(f1, t0 + dur);
    o.connect(g); g.connect(master);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(vol, t0 + 0.004);
    g.gain.linearRampToValueAtTime(0.0001, t0 + dur);
    o.start(t0); o.stop(t0 + dur + 0.02);
  };
  const tick = (pitch = 1, vol = 1) => { if (vol > 0.01) sq(1250 * pitch, 0.018, 0.028 * vol); };
  const bleep2 = (a, b) => { sq(a, 0.06, 0.05); sq(b, 0.06, 0.05, 0.075); };
  const buzz = () => { sq(196, 0.12, 0.05); sq(98, 0.12, 0.03, 0.005, "triangle"); };
  const fanfare = () => {
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
      sq(f, 0.07, 0.05, i * 0.08);
      sq(f / 2, 0.07, 0.025, i * 0.08, "triangle");
    });
    [523.25, 659.25, 783.99].forEach((f) => sq(f, 0.28, 0.035, 0.36));
    sq(1567.98, 0.28, 0.02, 0.36);
  };
  const boing = (i = 0.5) => sweep(420 + 200 * i, 150, 0.09, 0.05 * i + 0.015);
  const thud = () => sq(180, 0.035, 0.022, 0, "triangle");
  const pip = () => sq(880, 0.03, 0.04);
  const sleepy = () => { sq(392, 0.09, 0.03, 0, "triangle"); sq(261.63, 0.12, 0.03, 0.11, "triangle"); };
  const wake = () => sq(1046.5, 0.04, 0.04);
  const pat = () => { sq(523.25, 0.06, 0.04, 0, "triangle"); sq(659.25, 0.09, 0.04, 0.07, "triangle"); };
  const setMuted = (m) => { muted = m; if (master) master.gain.value = m ? 0 : 0.5; };
  return { ensure, tick, bleep2, buzz, fanfare, boing, thud, pip, sleepy, wake, pat, setMuted };
}

/* ---------- css ---------- */
const CSS = `
.pip-stage { height: 100vh; height: 100dvh; }
.pip-fade { transition: opacity .3s ease; }
@keyframes pipRoll {
  from { transform: translateY(-90px); }
  to   { transform: translateY(110vh); }
}
.pip-btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 5px;
  border: 1px solid rgba(186,242,208,.25);
  background: rgba(186,242,208,.05);
  color: rgba(186,242,208,.75);
  border-radius: 3px; padding: 5px 11px;
  font-size: 11px; font-weight: 600; letter-spacing: .12em;
  cursor: pointer; user-select: none; -webkit-user-select: none;
  transition: background .15s ease, color .15s ease;
  white-space: nowrap; text-transform: uppercase;
  font-family: ui-monospace, 'SF Mono', Menlo, monospace;
}
.pip-btn:hover { background: rgba(186,242,208,.14); color: #eafff3; }
.pip-btn:focus-visible { outline: 1.5px solid rgba(186,242,208,.6); outline-offset: 2px; }
.pip-btn.on { background: #baf2d0; color: #101216; border-color: #baf2d0; }
.pip-btn.icon { padding: 5px; width: 26px; height: 26px; }
@media (prefers-reduced-motion: reduce) {
  .pip-anim * { animation-duration: .01s !important; }
}
`;

/* ---------- component ---------- */
export default function PipTimer() {
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
    nextFidget: Infinity,
    freeFlight: false,
    settle: 0, lastInteract: 0, wakeUntil: 0,
    sleeping: false, wakeFlash: -1e9,
    hearts: 0,
    conf: [], zs: [], sweats: [],
    lastZ: 0, lastSweat: 0,
    flashT: -1e9,
    hopY: 0, hopV: 0, prevHopY: 0, landT: -1e9,
    ahX: 0,
    doneT: -1e9, prevSegs: -1, segPopT: -1e9, segPopI: -1,
    noticeT: -1e9, prevHovered: false, lastAutoHop: 0,
    pressT: 0, patT: -1e9, miniHearts: [],
    flyHeart: null, happyUntil: -1e9, sadUntil: -1e9,
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
    audioRef.current.bleep2(659.25, 987.77);
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
    audioRef.current.wake();
  };
  const reset = () => {
    if (S.mode === "running" || S.mode === "paused") {
      const rem = S.mode === "running" ? Math.max(0, S.endAt - Date.now()) : S.remainingMs;
      if (S.durationMs - rem > 15000) S.sadUntil = performance.now() + 5000;
    }
    S.remainingMs = S.durationMs;
    S.fired = {};
    setMode("idle");
  };
  const finish = () => {
    S.remainingMs = 0;
    S.freeFlight = false;
    setMode("done");
    S.flyHeart = { x: 28, y: 18, t0: performance.now() + 900 };
    S.happyUntil = performance.now() + 9000;
    S.doneT = performance.now();
    audioRef.current.fanfare();
    const wave = (n) => {
      for (let i = 0; i < n; i++) {
        S.conf.push({
          x: 28 + (Math.random() - 0.5) * 10,
          y: 22,
          vx: (Math.random() - 0.5) * 40,
          vy: -30 - Math.random() * 45,
          c: [MINT, AMBER, PINK, CYAN, "#ffffff"][i % 5],
          life: 1.4 + Math.random() * 0.5,
        });
      }
    };
    if (!S.reduceMotion) {
      S.hopV = -46;
      wave(28);
      later(() => wave(16), 600);
    }
    S.home = { x: S.size.w / 2, y: S.size.h / 2 - 20 };
    later(() => { if (S.mode === "done") reset(); }, 6000);
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
    audioRef.current.pip();
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
        audioRef.current.pip();
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
    // draw body with a lean: top rows shifted into the direction of travel
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
            audioRef.current.bleep2(659.25, 783.99);
            S.flashT = t; S.wakeUntil = t + 2600;
            if (!rm) S.hopV = -34;
          }
          if (dms >= 240000 && rms <= dms * 0.25 && !S.fired.quarter) {
            S.fired.quarter = true;
            audioRef.current.bleep2(783.99, 987.77);
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
      const panic = running && remS <= 10;

      /* settle -> sleep */
      const settleTarget =
        running && !S.hovered && !S.dragging && !S.freeFlight &&
        t > S.wakeUntil && t - S.lastInteract > 10000 && remS > 75 ? 1 : 0;
      S.settle += (settleTarget - S.settle) *
        Math.min(1, dt * (settleTarget > S.settle ? 0.35 : 2.8));
      const sleeping = S.settle > 0.6;
      if (sleeping !== S.sleeping) {
        S.sleeping = sleeping;
        if (sleeping) audioRef.current.sleepy();
        else { audioRef.current.wake(); S.wakeFlash = t; }
      }
      const bored = S.mode === "idle" && t - S.lastInteract > 30000;

      /* breath */
      let period =
        S.mode === "paused" ? 5.5 :
        S.mode === "idle" ? 3.2 :
        S.mode === "done" ? 0.9 :
        lerp(3.2, 1.0, p * p);
      if (panic) period = 0.45;
      period *= 1 + 0.8 * S.settle;
      S.phase += (TAU * dt) / period;

      /* blink / wink */
      if (t > S.nextBlink && !sleeping && !rm) {
        S.blinkT = t;
        S.winking = Math.random() < 0.25;
        S.nextBlink = Math.random() < 0.2 ? t + 300 : t + 2800 + Math.random() * 5000;
      }
      const blinking = t - S.blinkT < 140;

      /* fidgets */
      if (S.mode === "idle" && !S.dragging && !rm && !bored && t > S.nextFidget) {
        const r = Math.random();
        if (r < 0.35) {
          S.home.x = clamp(
            S.home.x + (Math.random() < 0.5 ? -1 : 1) * (50 + Math.random() * 45),
            90, S.size.w - 90);
        }
        else if (r < 0.6) S.hopV = -32;
        else if (r < 0.85) { S.glance = { x: (Math.random() - 0.5) * 8, y: 0 }; S.glanceUntil = t + 900; }
        else S.vel.x += (Math.random() < 0.5 ? -1 : 1) * 70;
        S.nextFidget = t + 8000 + Math.random() * 9000;
      }
      if (S.mode !== "idle") S.nextFidget = t + 7000;

      /* hop physics (in canvas pixels) */
      S.prevHopY = S.hopY;
      S.hopV += 260 * dt;
      S.hopY += S.hopV * dt;
      if (S.hopY >= 0) {
        if (S.prevHopY < -0.6 && !rm) {
          S.landT = t;
          audioRef.current.thud();
        }
        S.hopY = 0; S.hopV = 0;
      }
      const landing = t - S.landT < 100;

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
        const stiff = S.dragging ? 380 : 90;
        const damp = S.dragging ? 26 : 11;
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

      /* ahoge lag spring */
      const ahTarget = clamp(-S.vel.x / 260, -1.6, 1.6) + Math.sin(S.phase) * 0.25;
      S.ahX += (ahTarget - S.ahX) * Math.min(1, dt * 9);

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

      /* celebrate hop loop */
      if (S.mode === "done" && !rm && S.hopY === 0 && t - S.lastAutoHop > 650) {
        S.lastAutoHop = t;
        S.hopV = -34;
      }

      /* hover notice */
      if (S.hovered !== S.prevHovered) {
        S.prevHovered = S.hovered;
        if (S.hovered) S.noticeT = t;
      }

      /* particles */
      if (sleeping && t - S.lastZ > 1700 && !rm) {
        S.lastZ = t;
        S.zs.push({ x: 38, y: 14, life: 1.8 });
      }
      if (panic && t - S.lastSweat > 900 && !rm) {
        S.lastSweat = t;
        S.sweats.push({ x: 20, y: 16, vx: 9, vy: -6, life: 0.9 });
      }
      S.conf.forEach((c) => { c.vy += 65 * dt; c.x += c.vx * dt; c.y += c.vy * dt; c.life -= dt; });
      S.conf = S.conf.filter((c) => c.life > 0 && c.y < 47);
      S.zs.forEach((z) => { z.y -= 3.5 * dt; z.x += Math.sin(t / 400) * 1.5 * dt; z.life -= dt; });
      S.zs = S.zs.filter((z) => z.life > 0);
      S.sweats.forEach((s) => { s.x += (s.vx || 0) * dt; s.y += s.vy * dt; s.vy += 42 * dt; s.life -= dt; });
      S.sweats = S.sweats.filter((s) => s.life > 0);
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
        if (k >= 1) { S.flyHeart = null; S.hearts += 1; audioRef.current.pip(); }
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
        drawText(g, "YAY", Math.round(28 - textW("YAY") / 2), 2,
          Math.floor(t / 180) % 2 ? AMBER : "#ffffff");
      }

      const frac = S.mode === "idle" ? 1 : clamp(S.remainingMs / S.durationMs, 0, 1);
      const segs = Math.ceil(frac * 20);
      if (segs < S.prevSegs && running) { S.segPopT = t; S.segPopI = segs; }
      S.prevSegs = segs;
      let barC = MINT;
      if (running && remS <= 60) barC = AMBER;
      if (panic) barC = Math.floor(t / 250) % 2 ? RED : AMBER;
      for (let i = 0; i < 20; i++) {
        const popping = i === S.segPopI && t - S.segPopT < 130;
        px(g, 8 + i * 2, 41, popping ? "#eafff3" : i < segs ? barC : SLOT, 1, 3);
      }

      /* creature */
      const squashing = landing || S.scale < 0.92;
      const sit = bored && !squashing;
      const bounce = sleeping || sit ? 0 : Math.round(Math.sin(S.phase) * (panic ? 1 : 1.2));
      const shake = panic && !rm ? Math.round((Math.random() - 0.5) * 2) : 0;
      const lift = Math.round(S.hopY);
      const bx = 21 + shake;
      const by = 20 + bounce + lift + (sit ? 1 : 0) + (squashing ? 2 : 0);

      /* ground shadow (fixed floor, shrinks when airborne / hopping) */
      if (!airborne) {
        const h = Math.min(4, Math.abs(lift) + (squashing ? 0 : Math.max(0, -bounce)));
        const w = 9 - h;
        px(g, 28 - Math.floor(w / 2), 31, SHADOW, w, 1);
      }

      const lean = walking ? (S.vel.x > 0 ? 1 : -1) : 0;
      const bodyRows = squashing ? BODY_SQ : BODY;
      if (lean) spriteLean(g, bodyRows, bx, by, MINT, lean);
      else sprite(g, bodyRows, bx, by, MINT);
      const bodyH = bodyRows.length;
      px(g, bx + 1, by + bodyH - 1, MINT_DIM, 11, 1);

      /* feet */
      let feet;
      if (S.dragging || S.freeFlight) feet = Math.floor(t / 260) % 2 ? DANGLE_A : DANGLE_B;
      else if (sit) feet = FEET_SIT;
      else if (squashing) feet = FEET_A;
      else feet = walking ? (Math.floor(t / 130) % 2 ? FEET_A : FEET_B) : FEET_A;
      sprite(g, [feet], bx, by + bodyH, MINT);

      /* ahoge */
      const ah = Math.round(S.ahX);
      px(g, bx + 6, by - 1, MINT);
      px(g, bx + 6 + clamp(ah, -1, 1), by - 2, MINT);

      /* landing dust */
      if (landing && !rm) {
        px(g, bx - 1, by + bodyH, MINT_DIM);
        px(g, bx + 13, by + bodyH, MINT_DIM);
      }

      /* face */
      const eox = clamp(Math.round(S.gaze.x / 2.4), -1, 1);
      const eoy = S.dragging ? 1 : clamp(Math.round(S.gaze.y / 3), -1, 1);
      const eyeRow = squashing ? by + 2 : by + 3;
      const worried = (S.freeFlight || (S.dragging && speed > 420));
      if (S.mode === "done") {
        px(g, bx + 3, eyeRow, EYE); px(g, bx + 2, eyeRow + 1, EYE); px(g, bx + 4, eyeRow + 1, EYE);
        px(g, bx + 9, eyeRow, EYE); px(g, bx + 8, eyeRow + 1, EYE); px(g, bx + 10, eyeRow + 1, EYE);
        px(g, bx + 5, eyeRow + 3, EYE, 3, 1);
        px(g, bx + 1, eyeRow + 2, PINK); px(g, bx + 11, eyeRow + 2, PINK);
      } else if (t - S.patT < 900 || (t < S.happyUntil && !panic && !sleeping)) {
        px(g, bx + 3, eyeRow + 1, EYE, 2, 1);
        px(g, bx + 8, eyeRow + 1, EYE, 2, 1);
        px(g, bx + 1, eyeRow + 2, PINK); px(g, bx + 11, eyeRow + 2, PINK);
        px(g, bx + 5, eyeRow + 3, EYE, 3, 1);
      } else if (t < S.sadUntil) {
        px(g, bx + 3, eyeRow + 1, EYE, 2, 1);
        px(g, bx + 8, eyeRow + 1, EYE, 2, 1);
        px(g, bx + 5, eyeRow + 3, EYE); px(g, bx + 7, eyeRow + 3, EYE);
        px(g, bx + 6, eyeRow + 4, EYE);
      } else if (sleeping || S.mode === "paused") {
        px(g, bx + 3, eyeRow + 1, EYE, 2, 1);
        px(g, bx + 8, eyeRow + 1, EYE, 2, 1);
      } else if (blinking) {
        if (S.winking) {
          px(g, bx + 3, eyeRow + 1, EYE, 2, 1);
          px(g, bx + 9 + eox, eyeRow + eoy, EYE, 1, 2);
        } else {
          px(g, bx + 3, eyeRow + 1, EYE, 2, 1);
          px(g, bx + 8, eyeRow + 1, EYE, 2, 1);
        }
      } else if (panic || worried) {
        px(g, bx + 2 + eox, eyeRow, EYE, 2, 2);
        px(g, bx + 8 + eox, eyeRow, EYE, 2, 2);
        px(g, bx + 5, eyeRow + 3, EYE, 2, 1);
      } else if (t - S.noticeT < 250) {
        px(g, bx + 2 + eox, eyeRow, EYE, 2, 2);
        px(g, bx + 8 + eox, eyeRow, EYE, 2, 2);
      } else {
        px(g, bx + 3 + eox, eyeRow + eoy, EYE, 1, 2);
        px(g, bx + 9 + eox, eyeRow + eoy, EYE, 1, 2);
      }

      if (t - S.wakeFlash < 450) {
        px(g, bx + 6, by - 7, AMBER, 1, 3);
        px(g, bx + 6, by - 3, AMBER);
      }
      if (panic && Math.floor(t / 400) % 2 === 0) {
        px(g, bx + 3, by - 6, RED, 1, 3); px(g, bx + 3, by - 2, RED);
        px(g, bx + 9, by - 6, RED, 1, 3); px(g, bx + 9, by - 2, RED);
      }

      S.zs.forEach((z) => sprite(g, ZGLYPH, Math.round(z.x), Math.round(z.y), CYAN));
      S.sweats.forEach((s) => px(g, Math.round(s.x), Math.round(s.y), CYAN, 1, 2));
      S.conf.forEach((c) => px(g, Math.round(c.x), Math.round(c.y), c.c));

      if (t - S.flashT < 90) {
        g.fillStyle = "rgba(186,242,208,.16)";
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
        audioRef.current.pat();
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
      className="pip-anim pip-stage"
      style={{
        position: "relative", width: "100%", overflow: "hidden",
        background: "radial-gradient(115% 100% at 50% 40%, #14171c 0%, #101216 55%, #0a0c0f 100%)",
        fontFamily: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace",
        userSelect: "none", WebkitUserSelect: "none",
      }}
    >
      <style>{CSS}</style>

      <div style={{ position: "absolute", top: 22, left: 26, pointerEvents: "none" }}>
        <div style={{ color: "rgba(186,242,208,.85)", fontSize: 13, fontWeight: 700, letterSpacing: ".22em" }}>
          PIP
        </div>
        <div style={{ color: "rgba(143,216,180,.45)", fontSize: 10.5, marginTop: 3, letterSpacing: ".08em" }}>
          PIXEL PAL TIMER — V4.3 · PERSONALITY
        </div>
      </div>

      <div style={{
        position: "absolute", bottom: 20, left: 0, right: 0,
        textAlign: "center", pointerEvents: "none",
        color: "rgba(143,216,180,.4)", fontSize: 10.5, letterSpacing: ".1em",
        padding: "0 16px", textTransform: "uppercase",
      }}>
        {coarse
          ? "tap pip to start · hold to pat · drag or fling anywhere"
          : <>tap pip to start · hold to pat · drag or fling anywhere
              <span style={{ opacity: 0.7 }}> · scroll = time · space / R / M</span></>}
      </div>

      <div
        ref={wrapperRef}
        aria-label="pixel pet timer"
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
          background: "radial-gradient(circle, rgba(186,242,208,.14) 0%, rgba(186,242,208,0) 62%)",
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

        <div className="pip-fade" style={{
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
                  className={`pip-btn ${durationMs === pr.ms ? "on" : ""}`}
                  onClick={() => pickDuration(pr.ms)}
                  aria-label={`set timer to ${pr.label}`}>
                  {pr.label}
                </button>
              ))}
              <button className="pip-btn icon" onClick={toggleMute} title="mute (M)" aria-label="toggle sound">
                {muted ? <VolumeX size={12} /> : <Volume2 size={12} />}
              </button>
            </>
          ) : (
            <>
              <button className="pip-btn icon"
                onClick={() => (mode === "running" ? pause() : resume())}
                title="pause / resume (space)"
                aria-label={mode === "running" ? "pause timer" : "resume timer"}>
                {mode === "running" ? <Pause size={12} /> : <Play size={12} />}
              </button>
              <button className="pip-btn icon" onClick={toggleMute} title="mute (M)" aria-label="toggle sound">
                {muted ? <VolumeX size={12} /> : <Volume2 size={12} />}
              </button>
              <button className="pip-btn icon" onClick={reset} title="reset (R)" aria-label="reset timer">
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
        animation: "pipRoll 7s linear infinite",
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