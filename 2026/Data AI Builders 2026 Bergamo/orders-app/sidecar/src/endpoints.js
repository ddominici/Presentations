// Elenco CHIUSO delle query esposte: nessun endpoint accetta SQL libero.
// Le scelte dell'utente sono solo parametri legati ($1, $2, ...) o valori da liste ammesse.
import { embed, toVectorLiteral } from './embedding.js';

const fail = (message) => Object.assign(new Error(message), { status: 400 });

const text = (name, { required = true, max = 200 } = {}) => (q) => {
  const v = q.get(name);
  if (v === null || v === '') {
    if (required) throw fail(`Parametro obbligatorio: ${name}`);
    return null;
  }
  if (v.length > max) throw fail(`Parametro troppo lungo: ${name}`);
  return v;
};
const num = (name, { min, max, def }) => (q) => {
  const raw = q.get(name);
  if (raw === null || raw === '') return def;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < min || n > max) throw fail(`${name} deve essere tra ${min} e ${max}`);
  return n;
};

/**
 * Ogni voce: `params` (parser), `sql` (chiamata della funzione), e opzionalmente
 *  - `fn`   funzione di cui mostrare il sorgente
 *  - `plan` costruisce una query equivalente "inline" per EXPLAIN (con indice se esiste)
 *  - `prepare` asincrono: calcola l'embedding della query fuori dal database
 *  - `setup`   istruzioni da eseguire prima (soglie pg_trgm)
 */
export const SEARCHES = {
  attributes: {
    feature: 'jsonb', fn: 'find_products_by_attributes',
    params: { contains: text('contains', { required: false }), has_key: text('has_key', { required: false }), path: text('path', { required: false }) },
    sql: 'SELECT * FROM shop.find_products_by_attributes($1, $2, $3)',
    args: (p) => [p.contains, p.has_key, p.path],
    plan: (p) => {
      const where = []; const args = [];
      if (p.contains) { args.push(p.contains); where.push(`attributes @> $${args.length}::jsonb`); }
      if (p.has_key) { args.push(p.has_key); where.push(`attributes ? $${args.length}`); }
      if (p.path) { args.push(p.path); where.push(`attributes @? $${args.length}::jsonpath`); }
      return { sql: `SELECT id FROM shop.products WHERE ${where.join(' AND ') || 'true'}`, args };
    },
  },
  fts: {
    feature: 'fts', fn: 'search_products_fts',
    params: { q: text('q'), limit: num('limit', { min: 1, max: 50, def: 20 }) },
    sql: 'SELECT * FROM shop.search_products_fts($1, $2)',
    args: (p) => [p.q, p.limit],
    plan: (p) => ({ sql: `SELECT id FROM shop.products WHERE search_vector @@ websearch_to_tsquery('italian', $1)`, args: [p.q] }),
  },
  'fts-explain': {
    feature: 'fts', fn: 'explain_text_search',
    params: { q: text('q') },
    sql: 'SELECT * FROM shop.explain_text_search($1)', args: (p) => [p.q],
  },
  customers: {
    feature: 'trgm', fn: 'search_customers',
    params: { q: text('q'), threshold: num('threshold', { min: 0.05, max: 0.95, def: 0.3 }) },
    sql: 'SELECT * FROM shop.search_customers($1, $2::real)', args: (p) => [p.q, p.threshold],
    plan: (p) => ({
      sql: `SELECT id FROM shop.customers WHERE name % $1 OR $1 <% name OR name ILIKE '%' || $1 || '%'`, args: [p.q],
      setup: [["SELECT set_config('pg_trgm.similarity_threshold', $1, true), set_config('pg_trgm.word_similarity_threshold', $1, true)", [String(p.threshold)]]],
    }),
  },
  fuzzy: {
    feature: 'trgm', fn: 'search_products_fuzzy',
    params: { q: text('q'), threshold: num('threshold', { min: 0.05, max: 0.95, def: 0.3 }) },
    sql: 'SELECT * FROM shop.search_products_fuzzy($1, $2::real)', args: (p) => [p.q, p.threshold],
    plan: (p) => ({
      sql: `SELECT id FROM shop.products WHERE name % $1 OR $1 <% name`, args: [p.q],
      setup: [["SELECT set_config('pg_trgm.similarity_threshold', $1, true), set_config('pg_trgm.word_similarity_threshold', $1, true)", [String(p.threshold)]]],
    }),
  },
  trigrams: {
    feature: 'trgm', fn: 'trigrams_of',
    params: { q: text('q', { max: 60 }) },
    sql: 'SELECT * FROM shop.trigrams_of($1)', args: (p) => [p.q],
  },
  suggest: {
    feature: 'trgm', fn: 'suggest_terms',
    params: { q: text('q', { max: 60 }) },
    sql: 'SELECT * FROM shop.suggest_terms($1)', args: (p) => [p.q],
  },
  semantic: {
    feature: 'vector', fn: 'search_products_semantic',
    params: { q: text('q'), limit: num('limit', { min: 1, max: 30, def: 10 }) },
    prepare: async (p) => ({ ...p, embedding: toVectorLiteral(await embed(p.q)) }),
    sql: 'SELECT * FROM shop.search_products_semantic($1, $2)', args: (p) => [p.embedding, p.limit],
    plan: (p) => ({ sql: `SELECT id FROM shop.products ORDER BY embedding <=> $1::vector LIMIT $2`, args: [p.embedding, p.limit] }),
    hideArgs: [0],
  },
  hybrid: {
    feature: 'vector', fn: 'search_products_hybrid',
    params: { q: text('q'), limit: num('limit', { min: 1, max: 30, def: 10 }) },
    prepare: async (p) => ({ ...p, embedding: toVectorLiteral(await embed(p.q)) }),
    sql: 'SELECT * FROM shop.search_products_hybrid($1, $2, $3)', args: (p) => [p.q, p.embedding, p.limit],
    hideArgs: [1],
  },
  similar: {
    feature: 'vector', fn: 'similar_products',
    params: { product_id: num('product_id', { min: 1, max: 1e9, def: null }), limit: num('limit', { min: 1, max: 20, def: 5 }) },
    sql: 'SELECT * FROM shop.similar_products($1, $2)', args: (p) => [p.product_id, p.limit],
  },
};

export function parseParams(spec, query) {
  return Object.fromEntries(Object.entries(spec.params).map(([k, parse]) => [k, parse(query)]));
}

/** Funzioni di cui è consentito mostrare il sorgente */
export const FUNCTION_SOURCES = new Set([
  ...Object.values(SEARCHES).map((s) => s.fn), 'create_order', 'refresh_product_words',
]);

/** Dimostrazioni RLS: istruzioni fisse, eseguite in una transazione che viene sempre annullata. */
export const RLS_ATTEMPTS = {
  see_orders: {
    title: 'Elenco ordini: stessa query, ruoli diversi',
    sql: 'SELECT region, count(*)::int AS orders FROM shop.orders GROUP BY region ORDER BY region',
  },
  move_region: {
    title: 'Spostare un ordine in un\'altra regione (WITH CHECK)',
    sql: `UPDATE shop.orders SET region = CASE WHEN region = 'milano' THEN 'bergamo' ELSE 'milano' END
           WHERE id = (SELECT min(id) FROM shop.orders WHERE status = 'new')`,
  },
  edit_closed: {
    title: 'Modificare un ordine consegnato (policy RESTRICTIVE)',
    sql: `UPDATE shop.orders SET notes = 'tentativo' WHERE id = (SELECT min(id) FROM shop.orders WHERE status = 'delivered')`,
  },
  delete_open: {
    title: 'Cancellare un ordine già confermato (policy RESTRICTIVE sul DELETE)',
    sql: `DELETE FROM shop.orders WHERE id = (SELECT min(id) FROM shop.orders WHERE status = 'confirmed')`,
  },
  other_region: {
    title: 'Aggiornare un ordine di un\'altra regione (riga non visibile)',
    sql: `UPDATE shop.orders SET notes = 'intruso'
           WHERE id = (SELECT min(id) FROM shop.orders WHERE region = CASE shop.current_region() WHEN 'milano' THEN 'bergamo' ELSE 'milano' END)`,
  },
  write_catalog: {
    title: 'Scrivere nel catalogo prodotti (privilegi, non RLS)',
    sql: `UPDATE shop.products SET price = price WHERE id = 1`,
  },
  row_security_off: {
    title: 'SET row_security = off (non disattiva RLS)',
    sql: `SET LOCAL row_security = off; SELECT count(*)::int AS orders FROM shop.orders`,
    multi: true,
  },
};
