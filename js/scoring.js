/**
 * scoring.js — Pure scoring state machines for each sport.
 *
 * Each sport exports a strategy object with:
 *   applyPoint(state, playerIndex) → new state (immutable)
 *   getDisplayScore(state)         → { p1, p2, extra } display strings
 *   initState(config)              → initial state object
 */

'use strict';

// ─── Helpers ────────────────────────────────────────────────────────────────

function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function checkMatchOver(state) {
  const needed = Math.ceil(state.bestOf / 2);
  if (state.setsWon[0] >= needed) { state.matchOver = true; state.winner = 0; }
  if (state.setsWon[1] >= needed) { state.matchOver = true; state.winner = 1; }
}

function startNextGame(state, gameWinner) {
  state.setsWon[gameWinner]++;
  state.gamesHistory.push({ points: [...state.points] });
  checkMatchOver(state);
  if (!state.matchOver) {
    state.currentGame++;
    state.points = [0, 0];
  }
}

// ─── Badminton ───────────────────────────────────────────────────────────────

const Badminton = {
  initState(config) {
    return {
      sport: 'badminton',
      sessionMode: config.sessionMode || false, // unlimited games
      bestOf: config.sessionMode ? null : (config.bestOf || 3),
      targetScore: config.targetScore || 21,   // 21 or 11
      setsWon: [0, 0],
      currentGame: 1,
      gamesHistory: [],
      points: [0, 0],
      server: config.initialServer ?? 0,
      initialServer: config.initialServer ?? 0,
      matchOver: false,
      gameOver: false,        // session mode: game ended, waiting to continue
      lastGameWinner: null,   // session mode: winner of the just-finished game
      winner: null,
      startedAt: new Date().toISOString(),
      version: 1,
    };
  },

  applyPoint(state, player) {
    const s = deepClone(state);
    s.points[player]++;

    // Update server: winner of rally serves next
    s.server = player;

    const [p0, p1] = s.points;
    const gameOver = this._isGameOver(p0, p1, s.targetScore);
    if (gameOver !== null) {
      if (s.sessionMode) {
        // In session mode: record the game but don't reset — wait for continue
        s.setsWon[gameOver]++;
        s.gamesHistory.push({ points: [...s.points] });
        s.gameOver = true;
        s.lastGameWinner = gameOver;
      } else {
        startNextGame(s, gameOver);
        if (!s.matchOver) {
          // New game server: winner of last rally
          s.server = player;
        }
      }
    } else {
      // Change service when either player first reaches halfway in the deciding game
      // (only applies in bestOf mode; session mode has no deciding game)
      if (!s.sessionMode) {
        const decidingGame = Math.ceil(s.bestOf / 2) * 2 - 1;
        if (s.currentGame === decidingGame) {
          const halfway = Math.ceil(s.targetScore / 2);
          const prev = deepClone(state).points;
          const maxPrev = Math.max(prev[0], prev[1]);
          const maxNow = Math.max(s.points[0], s.points[1]);
          if (maxPrev < halfway && maxNow >= halfway) {
            s.server = s.points[0] >= halfway && s.points[0] > s.points[1] ? 0 : 1;
          }
        }
      }
    }

    return s;
  },

  // Called by scoreboard when player presses any button after a session game ends
  continueSession(state) {
    const s = deepClone(state);
    s.gameOver = false;
    s.currentGame++;
    s.points = [0, 0];
    s.server = s.lastGameWinner ?? 0; // winner of last game serves
    s.lastGameWinner = null;
    return s;
  },

  _isGameOver(p0, p1, targetScore = 21) {
    // First to targetScore, win by 2, max targetScore+9 (e.g. 30 for target=21, 20 for target=11)
    const max = targetScore + 9;
    if (p0 >= targetScore || p1 >= targetScore) {
      if (Math.abs(p0 - p1) >= 2) return p0 > p1 ? 0 : 1;
    }
    // At (max-1)-(max-1) the next point wins
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

// ─── Squash ──────────────────────────────────────────────────────────────────

const Squash = {
  initState(config) {
    return {
      sport: 'squash',
      bestOf: config.bestOf || 5,
      setsWon: [0, 0],
      currentGame: 1,
      gamesHistory: [],
      points: [0, 0],
      server: config.initialServer ?? 0,
      initialServer: config.initialServer ?? 0,
      matchOver: false,
      winner: null,
      startedAt: new Date().toISOString(),
      version: 1,
    };
  },

  applyPoint(state, player) {
    const s = deepClone(state);
    s.points[player]++;
    s.server = player; // rally-point: winner serves

    const [p0, p1] = s.points;
    const gameOver = this._isGameOver(p0, p1);
    if (gameOver !== null) {
      startNextGame(s, gameOver);
      if (!s.matchOver) s.server = player;
    }
    return s;
  },

  _isGameOver(p0, p1) {
    // First to 11, win by 2, no max
    if (p0 >= 11 || p1 >= 11) {
      if (Math.abs(p0 - p1) >= 2) return p0 > p1 ? 0 : 1;
    }
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

// ─── Table Tennis ────────────────────────────────────────────────────────────

const TableTennis = {
  initState(config) {
    return {
      sport: 'tabletennis',
      bestOf: config.bestOf || 5,
      setsWon: [0, 0],
      currentGame: 1,
      gamesHistory: [],
      points: [0, 0],
      server: config.initialServer ?? 0,
      initialServer: config.initialServer ?? 0,
      // server alternates every 2 points; at 10-10 every point
      serviceCount: 0, // points served by current server in this stint
      matchOver: false,
      winner: null,
      startedAt: new Date().toISOString(),
      version: 1,
    };
  },

  applyPoint(state, player) {
    const s = deepClone(state);
    s.points[player]++;
    s.serviceCount = (s.serviceCount || 0) + 1;

    const [p0, p1] = s.points;
    const deuce = p0 >= 10 && p1 >= 10;
    const switchEvery = deuce ? 1 : 2;

    if (s.serviceCount >= switchEvery) {
      s.server = 1 - s.server;
      s.serviceCount = 0;
    }

    const gameOver = this._isGameOver(p0, p1);
    if (gameOver !== null) {
      startNextGame(s, gameOver);
      if (!s.matchOver) {
        // New game: server is the one who received in the last game (alternates games)
        // Official rule: server of new game = receiver of last game's first service
        // Simplified: alternate who starts serving each game from initial server pattern
        s.server = (s.initialServer + s.currentGame - 1) % 2;
        s.serviceCount = 0;
      }
    }

    return s;
  },

  _isGameOver(p0, p1) {
    // First to 11, win by 2, no max
    if (p0 >= 11 || p1 >= 11) {
      if (Math.abs(p0 - p1) >= 2) return p0 > p1 ? 0 : 1;
    }
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

// ─── Tennis ──────────────────────────────────────────────────────────────────

const TENNIS_POINT_LABELS = ['0', '15', '30', '40'];

const Tennis = {
  initState(config) {
    return {
      sport: 'tennis',
      bestOf: config.bestOf || 3,
      setsWon: [0, 0],
      currentGame: 1,          // set number (1-indexed)
      gamesHistory: [],        // completed sets: { points: [gamesWon0, gamesWon1] }
      points: [0, 0],          // games won in current set
      server: config.initialServer ?? 0,
      initialServer: config.initialServer ?? 0,
      matchOver: false,
      winner: null,
      startedAt: new Date().toISOString(),
      version: 1,
      // Tennis-specific
      tennisGame: {
        rawPoints: [0, 0],     // 0-3 index into TENNIS_POINT_LABELS; 3 = 40
        deuce: false,
        advantage: null,        // null | 0 | 1
        tiebreak: false,
        tiebreakPoints: [0, 0],
        tiebreakServer: null,   // set when tiebreak starts
        tiebreakServiceCount: 0,
      },
      gamesServer: config.initialServer ?? 0, // tracks server across games in set
      totalGamesPlayed: 0,     // across all sets, for server rotation
    };
  },

  applyPoint(state, player) {
    const s = deepClone(state);
    const tg = s.tennisGame;

    if (tg.tiebreak) {
      return this._applyTiebreakPoint(s, player);
    }

    // Normal game point
    if (tg.deuce) {
      if (tg.advantage === null) {
        tg.advantage = player;
      } else if (tg.advantage === player) {
        // Win the game
        this._gameWon(s, player);
      } else {
        // Back to deuce
        tg.advantage = null;
      }
    } else {
      tg.rawPoints[player]++;
      if (tg.rawPoints[player] > 3) {
        // Shouldn't happen; guard
        tg.rawPoints[player] = 3;
      }
      if (tg.rawPoints[0] === 3 && tg.rawPoints[1] === 3) {
        tg.deuce = true;
      } else if (tg.rawPoints[player] === 4) {
        // Win the game (reached 40 and opponent not at 40 yet — shouldn't reach 4 normally)
        this._gameWon(s, player);
      } else if (tg.rawPoints[player] === 3 && tg.rawPoints[1 - player] < 3) {
        // At 40, if next point is scored we handle it next call
      }
    }

    // Check if game was won by rawPoints reaching 4 (edge: go 0,15,30,40 then win)
    // We handle win in the next point when rawPoints[player] was 3 and no deuce
    if (!tg.deuce && tg.rawPoints[player] > 3) {
      this._gameWon(s, player);
    }

    return s;
  },

  _applyTiebreakPoint(state, player) {
    const s = state;
    const tg = s.tennisGame;
    tg.tiebreakPoints[player]++;
    tg.tiebreakServiceCount++;

    // Server changes: first point, then every 2 points
    const count = tg.tiebreakServiceCount;
    if (count === 1) {
      // After first point, switch server
      s.server = 1 - tg.tiebreakServer;
      tg.tiebreakServiceCount = 0; // reset; next switch after 2
      // Actually: first serve is 1 point, then alternate every 2
      // Let's use a cleaner counter approach
    }

    // Simplified tiebreak server: starts with tiebreakServer, switches every 2 after first
    // Re-compute from total points served
    const total = tg.tiebreakPoints[0] + tg.tiebreakPoints[1];
    if (total === 1) {
      s.server = 1 - tg.tiebreakServer;
    } else {
      // After first point: switch every 2
      const subsequentPoints = total - 1;
      const switches = Math.floor((subsequentPoints - 1) / 2) + 1;
      s.server = (tg.tiebreakServer + 1 + switches) % 2;
    }

    const [tb0, tb1] = tg.tiebreakPoints;
    const tiebreakOver = (tb0 >= 7 || tb1 >= 7) && Math.abs(tb0 - tb1) >= 2;
    if (tiebreakOver) {
      const winner = tb0 > tb1 ? 0 : 1;
      s.points[winner]++;
      s.setsWon[winner]++;
      s.gamesHistory.push({ points: [...s.points] });
      checkMatchOver(s);
      if (!s.matchOver) {
        s.currentGame++;
        s.points = [0, 0];
        // After tiebreak: server is the one who received the tiebreak first serve
        s.server = 1 - tg.tiebreakServer;
        s.gamesServer = s.server;
        s.totalGamesPlayed++;
      }
      this._resetTennisGame(s);
    }

    return s;
  },

  _gameWon(state, player) {
    const s = state;
    s.points[player]++;
    s.totalGamesPlayed++;

    // Rotate server each game
    s.server = s.totalGamesPlayed % 2 === 0
      ? s.initialServer
      : 1 - s.initialServer;
    s.gamesServer = s.server;

    const [g0, g1] = s.points;
    const setOver = this._isSetOver(g0, g1, s);

    if (setOver !== null) {
      s.setsWon[setOver]++;
      s.gamesHistory.push({ points: [...s.points] });
      checkMatchOver(s);
      if (!s.matchOver) {
        s.currentGame++;
        s.points = [0, 0];
      }
    }

    this._resetTennisGame(s);

    // Check if tiebreak needed (6-6)
    if (!s.matchOver) {
      if (s.points[0] === 6 && s.points[1] === 6) {
        // Check if this is the final set in a BO5 — use advantage set (no tiebreak)
        const finalSet = s.currentGame === s.bestOf;
        if (!finalSet) {
          s.tennisGame.tiebreak = true;
          s.tennisGame.tiebreakServer = s.server;
          s.tennisGame.tiebreakPoints = [0, 0];
          s.tennisGame.tiebreakServiceCount = 0;
        }
        // If final set, play advantage set (win by 2, no max) — handled in _isSetOver
      }
    }
  },

  _isSetOver(g0, g1, state) {
    // First to 6, win by 2; tiebreak at 6-6 (handled elsewhere); advantage set in final
    const finalSet = state.currentGame === state.bestOf;
    if (g0 >= 6 || g1 >= 6) {
      if (Math.abs(g0 - g1) >= 2) return g0 > g1 ? 0 : 1;
      if (!finalSet && Math.abs(g0 - g1) === 0 && g0 === 7) return g0 > g1 ? 0 : 1; // tiebreak winner
      if (finalSet && Math.abs(g0 - g1) >= 2) return g0 > g1 ? 0 : 1; // advantage final set
    }
    // Tiebreak win (7-6 after tiebreak game is added)
    if (!finalSet && g0 === 7 && g1 === 6) return 0;
    if (!finalSet && g1 === 7 && g0 === 6) return 1;
    return null;
  },

  _resetTennisGame(state) {
    const tg = state.tennisGame;
    tg.rawPoints = [0, 0];
    tg.deuce = false;
    tg.advantage = null;
    tg.tiebreak = false;
    tg.tiebreakPoints = [0, 0];
    tg.tiebreakServer = null;
    tg.tiebreakServiceCount = 0;
  },

  getDisplayScore(state) {
    const tg = state.tennisGame;
    let p1, p2, extra = null;

    if (tg.tiebreak) {
      p1 = String(tg.tiebreakPoints[0]);
      p2 = String(tg.tiebreakPoints[1]);
      extra = 'TIEBREAK';
    } else if (tg.deuce) {
      p1 = 'DEUCE';
      p2 = 'DEUCE';
      if (tg.advantage === 0) { p1 = 'ADV'; p2 = '40'; extra = 'Advantage P1'; }
      if (tg.advantage === 1) { p2 = 'ADV'; p1 = '40'; extra = 'Advantage P2'; }
    } else {
      p1 = TENNIS_POINT_LABELS[tg.rawPoints[0]] ?? '0';
      p2 = TENNIS_POINT_LABELS[tg.rawPoints[1]] ?? '0';
    }

    return { p1, p2, extra };
  },
};

// ─── Registry ────────────────────────────────────────────────────────────────

const Sports = { badminton: Badminton, squash: Squash, tabletennis: TableTennis, tennis: Tennis };

// Fix: Tennis _gameWon rawPoints going to 4
// Patch applyPoint for Tennis normal game (non-deuce) so win is detected cleanly
Tennis.applyPoint = function(state, player) {
  const s = deepClone(state);
  const tg = s.tennisGame;

  if (tg.tiebreak) {
    return Tennis._applyTiebreakPoint(s, player);
  }

  if (tg.deuce) {
    if (tg.advantage === null) {
      tg.advantage = player;
    } else if (tg.advantage === player) {
      Tennis._gameWon(s, player);
    } else {
      tg.advantage = null;
    }
    return s;
  }

  // Normal play: 0→1→2→3(=40); next point at 3 = win (unless both at 3 = deuce)
  tg.rawPoints[player]++;
  const [r0, r1] = tg.rawPoints;

  if (r0 === 3 && r1 === 3) {
    tg.deuce = true;
  } else if (r0 > 3 || r1 > 3) {
    // Shouldn't happen; guard
  } else if (tg.rawPoints[player] === 3 && tg.rawPoints[1 - player] < 3) {
    // At 40, advantage; game won on next point — but we need to handle the
    // case where player had 40 and scores again:
    // Actually rawPoints maxes at 3 in our model. We detect win when
    // the *previous* state had player at rawPoints=3 (40) and now scores.
    // This means we need to check: was player at 3 before incrementing?
    // Since we already incremented, check if rawPoints[player] is now > 3... but we cap at 3.
    // Instead: detect if rawPoints went from 3 to... we need to re-examine.
    // The issue: after incrementing, if rawPoints[player] === 3 and opponent < 3, no win yet.
    // Win occurs when player already at 3 and scores again.
  }

  return s;
};

// Better Tennis applyPoint — track "game points" separately (0,1,2,3 = win)
Tennis.applyPoint = function(state, player) {
  const s = deepClone(state);
  const tg = s.tennisGame;

  if (tg.tiebreak) {
    return Tennis._applyTiebreakPoint(s, player);
  }

  // rawPoints[i] counts points 0..3; at 3 the player is at 40.
  // A 4th point (rawPoints would go to 4) means game won (if no deuce situation).
  // We represent winning the game by rawPoints reaching 4 then clearing.

  if (tg.deuce) {
    if (tg.advantage === null) {
      tg.advantage = player;
    } else if (tg.advantage === player) {
      Tennis._gameWon(s, player);
    } else {
      tg.advantage = null;
    }
    return s;
  }

  tg.rawPoints[player]++;

  const r0 = tg.rawPoints[0];
  const r1 = tg.rawPoints[1];

  if (r0 === 3 && r1 === 3) {
    // Both at 40: deuce
    tg.deuce = true;
  } else if (tg.rawPoints[player] >= 4) {
    // Won game (opponent was at <3 when this point scored)
    Tennis._gameWon(s, player);
  }

  return s;
};

// Ensure rawPoints can go to 4 as a win signal (init allows it; _resetTennisGame clears it)
// rawPoints is only displayed via getDisplayScore which maps index 0..3; 4 never displayed.
