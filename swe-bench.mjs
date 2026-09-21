import fs from 'node:fs';
import { normalizeModelSlug } from './providers.mjs';

export function loadSweBenchScores(filePath) {
  const map = new Map();
  let raw;
  try {
    raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return map;
  }
  for (const [key, value] of Object.entries(raw.scores || {})) {
    const n = Number(String(value).replace(/%/g, ''));
    if (!Number.isFinite(n)) continue;
    map.set(normalizeModelSlug(key), n);
  }
  return map;
}

export function sweBenchScoreFor(scores, modelId) {
  if (!scores?.size) return null;
  const n = scores.get(normalizeModelSlug(modelId));
  return Number.isFinite(n) ? n : null;
}
