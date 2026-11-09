// Embedding calcolati FUORI dal database, a monte. Il provider è sostituibile via configurazione.
//
//   EMBEDDING_PROVIDER=hash    (default) offline, deterministico, nessuna chiave.
//                              ATTENZIONE: NON è un modello semantico. Combina radici di parola,
//                              gruppi di sinonimi scritti a mano e trigrammi di caratteri in un vettore
//                              a 256 dimensioni: basta per mostrare pgvector, non per misurarne la qualità.
//   EMBEDDING_PROVIDER=openai  endpoint compatibile con /v1/embeddings (OpenAI, Ollama, ...).
//                              Servono EMBEDDING_BASE_URL e EMBEDDING_MODEL; EMBEDDING_API_KEY se richiesta.
//                              Il modello deve supportare il parametro `dimensions` = 256 (come la colonna vector(256)).

export const DIMENSIONS = 256;

const STOP = new Set(['il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una', 'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
  'e', 'o', 'che', 'chi', 'del', 'della', 'dei', 'delle', 'al', 'alla', 'ai', 'nel', 'nella', 'sul', 'sulla', 'si', 'non', 'piu', 'anche']);

// Gruppi di parole vicine di significato (scritti a mano per la demo; non sono apprendimento).
const SYNONYM_GROUPS = [
  ['portatile', 'notebook', 'laptop', 'ultrabook', 'mobilita', 'viaggio', 'viaggiare'],
  ['computer', 'pc', 'desktop', 'workstation', 'elaboratore'],
  ['schermo', 'monitor', 'display', 'pannello'],
  ['sedia', 'poltrona', 'seduta', 'ergonomica', 'ergonomico', 'schiena', 'lombare'],
  ['scrivania', 'tavolo', 'postazione', 'piano'],
  ['cuffie', 'cuffia', 'auricolari', 'headset', 'audio', 'microfono'],
  ['wireless', 'senzafili', 'bluetooth', 'wifi'],
  ['rete', 'network', 'ethernet', 'router', 'switch', 'internet'],
  ['stampante', 'stampa', 'toner', 'cartuccia', 'multifunzione', 'scansione'],
  ['archiviazione', 'storage', 'disco', 'ssd', 'backup', 'memoria', 'chiavetta', 'nas'],
  ['videochiamata', 'webcam', 'telecamera', 'videocamera', 'riunione', 'riunioni', 'conferenza', 'call'],
  ['mouse', 'tastiera', 'periferica', 'periferiche'],
  ['luce', 'lampada', 'illuminazione', 'led'],
  ['energia', 'alimentatore', 'caricabatterie', 'ricarica', 'continuita', 'batteria', 'corrente'],
  ['silenzioso', 'rumore', 'silenzio', 'concentrazione'],
];

const stem = (w) => (w.length > 6 ? w.slice(0, 6) : w);
const GROUP_OF = new Map();
SYNONYM_GROUPS.forEach((g, i) => g.forEach((w) => { GROUP_OF.set(stem(w), i); }));

export function tokenize(text) {
  return String(text)
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length > 1 && !STOP.has(t));
}

function fnv1a(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

function addFeature(vec, feature, weight) {
  const h = fnv1a(feature);
  const idx = h % DIMENSIONS;
  const sign = (fnv1a('s:' + feature) & 1) ? 1 : -1;   // feature hashing con segno
  vec[idx] += sign * weight;
}

export function hashEmbedding(text) {
  const vec = new Float64Array(DIMENSIONS);
  for (const token of tokenize(text)) {
    const s = stem(token);
    addFeature(vec, 'w:' + s, 1);
    if (GROUP_OF.has(s)) addFeature(vec, 'g:' + GROUP_OF.get(s), 1.5);
    const padded = `  ${s} `;
    for (let i = 0; i < padded.length - 2; i++) addFeature(vec, 't:' + padded.slice(i, i + 3), 0.25);
  }
  let norm = 0;
  for (const v of vec) norm += v * v;
  norm = Math.sqrt(norm) || 1;
  return Array.from(vec, (v) => v / norm);
}

async function openaiEmbedding(text, env) {
  const { EMBEDDING_BASE_URL: base, EMBEDDING_MODEL: model, EMBEDDING_API_KEY: key } = env;
  if (!base || !model) throw new Error('EMBEDDING_BASE_URL e EMBEDDING_MODEL sono obbligatori con EMBEDDING_PROVIDER=openai');
  const res = await fetch(`${base.replace(/\/$/, '')}/embeddings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) },
    body: JSON.stringify({ model, input: text, dimensions: DIMENSIONS }),
  });
  if (!res.ok) throw new Error(`Provider embedding: HTTP ${res.status}`);
  const json = await res.json();
  const emb = json?.data?.[0]?.embedding;
  if (!Array.isArray(emb) || emb.length !== DIMENSIONS) {
    throw new Error(`Il provider ha restituito ${emb?.length ?? 0} dimensioni, la colonna ne richiede ${DIMENSIONS}`);
  }
  return emb;
}

export function providerName(env = process.env) {
  return env.EMBEDDING_PROVIDER === 'openai' ? `openai-compatible (${env.EMBEDDING_MODEL || '?'})` : 'hash (offline, non semantico)';
}

export async function embed(text, env = process.env) {
  return env.EMBEDDING_PROVIDER === 'openai' ? openaiEmbedding(text, env) : hashEmbedding(text);
}

/** Formato testuale accettato dal tipo vector: '[0.1,0.2,...]' */
export const toVectorLiteral = (arr) => '[' + arr.map((v) => Number(v.toFixed(6))).join(',') + ']';
