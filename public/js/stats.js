/**
 * stats.js — Compute standings and head-to-head matrix from match history.
 */

'use strict';

/**
 * Compute season standings.
 * @param {Array} history — array of completed match records
 * @param {string|null} sport — filter by sport, or null for all
 * @returns {Array} sorted by wins desc, then winPct desc
 *   [{ playerId, playerName, wins, losses, winPct, setsWon, setsLost, gamesPlayed }]
 */
function computeStandings(history, sport = null) {
  const filtered = sport ? history.filter((m) => m.sport === sport) : history;

  const players = new Map(); // id → stats

  function getPlayer(id, name) {
    if (!players.has(id)) {
      players.set(id, {
        playerId: id,
        playerName: name,
        wins: 0,
        losses: 0,
        setsWon: 0,
        setsLost: 0,
        gamesPlayed: 0,
        totalSeconds: 0,
        totalRallySeconds: 0,
        rallyCount: 0,
      });
    }
    return players.get(id);
  }

  for (const match of filtered) {
    if (!Array.isArray(match.players) || match.players.length < 2) continue;
    const [p0, p1] = match.players;
    const s0 = getPlayer(p0.id, p0.name);
    const s1 = getPlayer(p1.id, p1.name);

    s0.gamesPlayed++;
    s1.gamesPlayed++;

    const [sw0, sw1] = match.setsWon || [0, 0];

    if (match.winner === 0) { s0.wins++; s1.losses++; }
    else if (match.winner === 1) { s1.wins++; s0.losses++; }

    s0.setsWon += sw0;
    s0.setsLost += sw1;
    s1.setsWon += sw1;
    s1.setsLost += sw0;

    // Duration tracking (both players share the same game time)
    const dur = match.durationSeconds || 0;
    s0.totalSeconds += dur;
    s1.totalSeconds += dur;

    const rallies = match.pointDurations || [];
    const rallyTotal = rallies.reduce((a, b) => a + b, 0);
    s0.totalRallySeconds += rallyTotal;
    s0.rallyCount += rallies.length;
    s1.totalRallySeconds += rallyTotal;
    s1.rallyCount += rallies.length;
  }

  const standings = Array.from(players.values()).map((p) => ({
    ...p,
    winPct: p.gamesPlayed > 0 ? Math.round((p.wins / p.gamesPlayed) * 100) : 0,
    avgGameSec: p.gamesPlayed > 0 ? Math.round(p.totalSeconds / p.gamesPlayed) : 0,
    avgRallySec: p.rallyCount > 0 ? Math.round(p.totalRallySeconds / p.rallyCount) : 0,
    totalMinutes: Math.round(p.totalSeconds / 60),
  }));

  standings.sort((a, b) => {
    if (b.wins !== a.wins) return b.wins - a.wins;
    return b.winPct - a.winPct;
  });

  return standings;
}

/**
 * Compute head-to-head records.
 * @param {Array} history
 * @param {string|null} sport
 * @returns {Map<string, Map<string, { wins, losses, playerName }>>}
 *   Outer key: playerId, inner key: opponentId
 */
function computeHeadToHead(history, sport = null) {
  const filtered = sport ? history.filter((m) => m.sport === sport) : history;

  const h2h = new Map(); // playerId → Map<opponentId → { wins, losses, opponentName }>

  function getRecord(id, name, oppId, oppName) {
    if (!h2h.has(id)) h2h.set(id, new Map());
    const inner = h2h.get(id);
    if (!inner.has(oppId)) {
      inner.set(oppId, { wins: 0, losses: 0, playerName: name, opponentName: oppName });
    }
    return inner.get(oppId);
  }

  for (const match of filtered) {
    if (!Array.isArray(match.players) || match.players.length < 2) continue;
    const [p0, p1] = match.players;

    const r0 = getRecord(p0.id, p0.name, p1.id, p1.name);
    const r1 = getRecord(p1.id, p1.name, p0.id, p0.name);

    if (match.winner === 0) { r0.wins++; r1.losses++; }
    else if (match.winner === 1) { r1.wins++; r0.losses++; }
  }

  return h2h;
}

/**
 * Get all unique players who appear in history.
 */
function getPlayersFromHistory(history) {
  const seen = new Map();
  for (const match of history) {
    for (const p of match.players || []) {
      if (p.id && !seen.has(p.id)) seen.set(p.id, p.name);
    }
  }
  return Array.from(seen.entries()).map(([id, name]) => ({ id, name }));
}
