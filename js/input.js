/**
 * input.js — Key mapping config and long-press detection.
 *
 * Usage:
 *   const handler = new InputHandler(keymap, { onPoint, onUndo });
 *   handler.attach();   // start listening
 *   handler.detach();   // stop listening
 *
 * keymap: { button1: 'ArrowLeft', button2: 'ArrowRight' }
 *   button1 → player 0 (left side)
 *   button2 → player 1 (right side)
 *
 * Long-press detection:
 *   - keydown: record timestamp, start 800ms timer
 *   - Timer fires: onUndo(), mark key as consumed
 *   - keyup: if not consumed → short press → onPoint(player)
 *   - Guard: activeKeys.has(key) on keydown → ignore (prevents iOS key-repeat)
 *   - Debounce: < 200ms since last point → skip
 */

'use strict';

const LONG_PRESS_MS = 800;
const DEBOUNCE_MS = 200;

class InputHandler {
  constructor(keymap, callbacks) {
    // keymap: { button1: key, button2: key }
    // callbacks: { onPoint(playerIndex), onUndo() }
    this.keymap = keymap;
    this.onPoint = callbacks.onPoint || (() => {});
    this.onUndo = callbacks.onUndo || (() => {});

    // key → player index reverse map
    this._keyToPlayer = {};
    if (keymap.button1) this._keyToPlayer[keymap.button1] = 0;
    if (keymap.button2) this._keyToPlayer[keymap.button2] = 1;

    this._activeKeys = new Set();       // keys currently held down
    this._timers = new Map();           // key → setTimeout id
    this._consumed = new Set();         // keys consumed by long-press (undo)
    this._lastPointTime = 0;            // timestamp of last point scored

    this._onKeyDown = this._onKeyDown.bind(this);
    this._onKeyUp = this._onKeyUp.bind(this);
  }

  attach() {
    document.addEventListener('keydown', this._onKeyDown);
    document.addEventListener('keyup', this._onKeyUp);
  }

  detach() {
    document.removeEventListener('keydown', this._onKeyDown);
    document.removeEventListener('keyup', this._onKeyUp);
    // Clear pending timers
    for (const timer of this._timers.values()) clearTimeout(timer);
    this._timers.clear();
    this._activeKeys.clear();
    this._consumed.clear();
  }

  _onKeyDown(e) {
    const key = e.key;

    // Only handle mapped keys
    if (!(key in this._keyToPlayer)) return;

    // Prevent default (scrolling, etc.)
    e.preventDefault();

    // iOS key-repeat guard: ignore if already tracking this key
    if (this._activeKeys.has(key)) return;

    this._activeKeys.add(key);

    // Start long-press timer
    const timer = setTimeout(() => {
      this._consumed.add(key);
      this._timers.delete(key);
      this.onUndo();
    }, LONG_PRESS_MS);

    this._timers.set(key, timer);
  }

  _onKeyUp(e) {
    const key = e.key;

    if (!(key in this._keyToPlayer)) return;
    e.preventDefault();

    // Clear long-press timer
    if (this._timers.has(key)) {
      clearTimeout(this._timers.get(key));
      this._timers.delete(key);
    }

    const consumed = this._consumed.has(key);
    this._consumed.delete(key);
    this._activeKeys.delete(key);

    if (consumed) return; // long-press already fired undo

    // Debounce rapid presses
    const now = Date.now();
    if (now - this._lastPointTime < DEBOUNCE_MS) return;
    this._lastPointTime = now;

    const player = this._keyToPlayer[key];
    this.onPoint(player);
  }
}

/**
 * Capture a single keypress for key mapping.
 * Returns a Promise<string> resolving with the key name.
 * Resolves on the first non-modifier keydown event.
 */
function captureKey() {
  return new Promise((resolve) => {
    const MODIFIERS = new Set(['Shift', 'Control', 'Alt', 'Meta', 'CapsLock', 'Fn', 'FnLock', 'Hyper', 'Super', 'Symbol', 'SymbolLock']);

    function handler(e) {
      if (MODIFIERS.has(e.key)) return;
      e.preventDefault();
      document.removeEventListener('keydown', handler);
      resolve(e.key);
    }

    document.addEventListener('keydown', handler);
  });
}
