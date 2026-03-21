/**
 * history.js — Match history read/write; export/import JSON.
 */

'use strict';

const HISTORY_KEY = 'scoreboard.history';
const PLAYERS_KEY = 'scoreboard.players';

function getAllMatches() {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]');
  } catch {
    return [];
  }
}

function saveAllMatches(matches) {
  localStorage.setItem(HISTORY_KEY, JSON.stringify(matches));
}

function appendMatch(record) {
  const matches = getAllMatches();
  matches.push(record);
  saveAllMatches(matches);
}

function getAllPlayers() {
  try {
    return JSON.parse(localStorage.getItem(PLAYERS_KEY) || '[]');
  } catch {
    return [];
  }
}

function saveAllPlayers(players) {
  localStorage.setItem(PLAYERS_KEY, JSON.stringify(players));
}

/**
 * Export players + history as a downloadable JSON file.
 */
function exportToJSON() {
  const data = {
    exportedAt: new Date().toISOString(),
    version: 1,
    players: getAllPlayers(),
    history: getAllMatches(),
  };

  const json = JSON.stringify(data, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);

  const today = new Date().toISOString().slice(0, 10);
  const a = document.createElement('a');
  a.href = url;
  a.download = `scoreboard-backup-${today}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Import from a JSON File object.
 * Merges by id — skips duplicates.
 * Returns a Promise<{ matchesAdded, playersAdded }>.
 */
function importFromJSON(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target.result);
        if (!data || !Array.isArray(data.history)) {
          throw new Error('Invalid backup file format');
        }

        // Merge history
        const existing = getAllMatches();
        const existingIds = new Set(existing.map((m) => m.id));
        const newMatches = (data.history || []).filter((m) => m.id && !existingIds.has(m.id));
        saveAllMatches([...existing, ...newMatches]);

        // Merge players
        const existingPlayers = getAllPlayers();
        const existingPlayerIds = new Set(existingPlayers.map((p) => p.id));
        const newPlayers = (data.players || []).filter((p) => p.id && !existingPlayerIds.has(p.id));
        saveAllPlayers([...existingPlayers, ...newPlayers]);

        resolve({ matchesAdded: newMatches.length, playersAdded: newPlayers.length });
      } catch (err) {
        reject(err);
      }
    };
    reader.onerror = () => reject(new Error('Failed to read file'));
    reader.readAsText(file);
  });
}
