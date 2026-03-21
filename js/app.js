/**
 * app.js — Scoreboard orchestration: scoring + input + DOM + storage.
 * Loaded by scoreboard.html.
 */

'use strict';

// ─── localStorage keys ───────────────────────────────────────────────────────
const KEY_CONFIG = 'scoreboard.config';
const KEY_STATE = 'scoreboard.state';
const KEY_UNDO = 'scoreboard.undoStack';
const MAX_UNDO = 50;

// ─── Helpers ─────────────────────────────────────────────────────────────────

function generateId() {
  return ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, (c) =>
    (c ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16)
  );
}

function loadConfig() {
  try { return JSON.parse(localStorage.getItem(KEY_CONFIG)); } catch { return null; }
}

function loadState() {
  try { return JSON.parse(localStorage.getItem(KEY_STATE)); } catch { return null; }
}

function saveState(state) {
  localStorage.setItem(KEY_STATE, JSON.stringify(state));
}

function loadUndoStack() {
  try { return JSON.parse(localStorage.getItem(KEY_UNDO) || '[]'); } catch { return []; }
}

function saveUndoStack(stack) {
  localStorage.setItem(KEY_UNDO, JSON.stringify(stack));
}

function pushUndo(state) {
  const stack = loadUndoStack();
  stack.push(JSON.parse(JSON.stringify(state)));
  if (stack.length > MAX_UNDO) stack.shift();
  saveUndoStack(stack);
}

function popUndo() {
  const stack = loadUndoStack();
  if (!stack.length) return null;
  const prev = stack.pop();
  saveUndoStack(stack);
  return prev;
}

// ─── DOM references ───────────────────────────────────────────────────────────

const $ = (id) => document.getElementById(id);

// ─── Main app ─────────────────────────────────────────────────────────────────

let config = null;
let state = null;
let sport = null;
let inputHandler = null;

function init() {
  config = loadConfig();
  if (!config) {
    window.location.href = 'index.html';
    return;
  }

  sport = Sports[config.sport];
  if (!sport) {
    alert('Unknown sport: ' + config.sport);
    window.location.href = 'index.html';
    return;
  }

  // Resume or start fresh
  state = loadState();
  if (!state || state.sport !== config.sport) {
    state = sport.initState(config);
    saveState(state);
    saveUndoStack([]);
  }

  // Set up input
  inputHandler = new InputHandler(config.keymap, {
    onPoint: handlePoint,
    onUndo: handleUndo,
  });
  inputHandler.attach();

  // iOS Safari: focus body to receive key events
  document.body.setAttribute('tabindex', '0');
  document.body.focus();

  // Initial render
  render(state);

  // Prevent double-tap zoom on scoreboard
  document.addEventListener('touchend', (e) => e.preventDefault(), { passive: false });
}

// ─── Point & Undo ─────────────────────────────────────────────────────────────

function handlePoint(player) {
  if (state.matchOver) return;
  pushUndo(state);
  state = sport.applyPoint(state, player);
  saveState(state);
  render(state);
  if (state.matchOver) onMatchOver();
}

function handleUndo() {
  const prev = popUndo();
  if (!prev) return;
  state = prev;
  saveState(state);
  render(state, { undo: true });
}

// ─── Match end ────────────────────────────────────────────────────────────────

function onMatchOver() {
  // Build and save match record
  const record = {
    id: generateId(),
    date: state.startedAt,
    sport: config.sport,
    bestOf: state.bestOf,
    players: config.playerIds.map((id, i) => ({ id, name: config.playerNames[i] })),
    winner: state.winner,
    setsWon: [...state.setsWon],
    gamesHistory: state.gamesHistory.map((g) => ({ points: [...g.points] })),
    durationSeconds: Math.round((Date.now() - new Date(state.startedAt).getTime()) / 1000),
  };
  appendMatch(record);

  showWinnerOverlay(state.winner);
}

function showWinnerOverlay(winner) {
  const overlay = $('winner-overlay');
  const nameEl = $('winner-name');
  nameEl.textContent = config.playerNames[winner];
  overlay.classList.remove('hidden');
}

// ─── Render ───────────────────────────────────────────────────────────────────

function render(st, opts = {}) {
  const display = sport.getDisplayScore(st);

  // Header
  $('sport-label').textContent = formatSportName(config.sport);
  $('game-info').textContent = `Game ${st.currentGame} of ${st.bestOf}`;

  // Player names + server indicator
  for (let i = 0; i < 2; i++) {
    $(`player-name-${i}`).textContent = config.playerNames[i] || `Player ${i + 1}`;
    const serverDot = $(`server-dot-${i}`);
    if (serverDot) serverDot.style.visibility = st.server === i ? 'visible' : 'hidden';
  }

  // Points (with flash on undo)
  const score0 = $('score-0');
  const score1 = $('score-1');
  score0.textContent = display.p1;
  score1.textContent = display.p2;

  if (opts.undo) {
    flashUndo(score0);
    flashUndo(score1);
  }

  // Sets won
  for (let i = 0; i < 2; i++) {
    $(`sets-won-${i}`).textContent = renderSets(st.setsWon[i]);
  }

  // Games history
  const hist = $('games-history');
  if (hist) {
    hist.textContent = st.gamesHistory
      .map((g) => `[${g.points[0]}-${g.points[1]}]`)
      .join(' ');
  }

  // Extra label (DEUCE, ADV, TIEBREAK)
  const extraEl = $('score-extra');
  if (extraEl) {
    extraEl.textContent = display.extra || '';
    extraEl.style.visibility = display.extra ? 'visible' : 'hidden';
  }

  // Tennis: game score row
  if (config.sport === 'tennis') {
    renderTennisGameScore(st);
  }

  // Sets row for sets (games count in tennis context = sets won label)
  $('sets-label-0').textContent = `Sets: ${st.setsWon[0]}`;
  $('sets-label-1').textContent = `Sets: ${st.setsWon[1]}`;
}

function renderTennisGameScore(st) {
  const gamesEl = $('tennis-games');
  if (!gamesEl) return;
  gamesEl.textContent = `${st.points[0]} – ${st.points[1]}`;
}

function renderSets(count) {
  return '●'.repeat(count) + '○'.repeat(Math.max(0, 3 - count));
}

function flashUndo(el) {
  el.classList.remove('undo-flash');
  // Trigger reflow to restart animation
  void el.offsetWidth;
  el.classList.add('undo-flash');
  setTimeout(() => el.classList.remove('undo-flash'), 300);
}

function formatSportName(sport) {
  const names = {
    badminton: 'BADMINTON',
    tennis: 'TENNIS',
    squash: 'SQUASH',
    tabletennis: 'TABLE TENNIS',
  };
  return names[sport] || sport.toUpperCase();
}

// ─── Rematch / New Match buttons ──────────────────────────────────────────────

function rematch() {
  // Swap initial server, reset scores, keep players
  const newInitialServer = 1 - (config.initialServer ?? 0);
  config.initialServer = newInitialServer;
  localStorage.setItem(KEY_CONFIG, JSON.stringify(config));

  state = sport.initState({ ...config, initialServer: newInitialServer });
  saveState(state);
  saveUndoStack([]);

  $('winner-overlay').classList.add('hidden');
  render(state);
}

function newMatch() {
  localStorage.removeItem(KEY_STATE);
  localStorage.removeItem(KEY_UNDO);
  window.location.href = 'index.html';
}

// Start
document.addEventListener('DOMContentLoaded', init);
