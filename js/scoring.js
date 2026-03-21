'use strict';

function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

// ─── Badminton ───────────────────────────────────────────────────────────────

const Badminton = {
  initState(config) {
    return {
      sport: 'badminton',
      sessionMode: true,
      targetScore: config.targetScore || 21,
      setsWon: [0, 0],
      currentGame: 1,
      gamesHistory: [],
      points: [0, 0],
      server: config.initialServer ?? 0,
      initialServer: config.initialServer ?? 0,
      gameOver: false,
      lastGameWinner: null,
      matchOver: false,
      winner: null,
      startedAt: new Date().toISOString(),
      version: 1,
    };
  },

  applyPoint(state, player) {
    const s = deepClone(state);
    s.points[player]++;
    s.server = player; // winner of rally serves next

    const [p0, p1] = s.points;
    const gameOver = this._isGameOver(p0, p1, s.targetScore);
    if (gameOver !== null) {
      s.setsWon[gameOver]++;
      s.gamesHistory.push({ points: [...s.points] });
      s.gameOver = true;
      s.lastGameWinner = gameOver;
    }

    return s;
  },

  continueSession(state) {
    const s = deepClone(state);
    s.gameOver = false;
    s.currentGame++;
    s.points = [0, 0];
    s.server = s.lastGameWinner ?? 0;
    s.lastGameWinner = null;
    return s;
  },

  _isGameOver(p0, p1, targetScore = 21) {
    // First to targetScore, win by 2, max targetScore+9 (e.g. 30 for 21, 20 for 11)
    const max = targetScore + 9;
    if (p0 >= targetScore || p1 >= targetScore) {
      if (Math.abs(p0 - p1) >= 2) return p0 > p1 ? 0 : 1;
    }
    if (p0 === max) return 0;
    if (p1 === max) return 1;
    return null;
  },

  getDisplayScore(state) {
    return {
      p1: String(state.points[0]),
      p2: String(state.points[1]),
      extra: null,
    };
  },
};

const Sports = { badminton: Badminton };
