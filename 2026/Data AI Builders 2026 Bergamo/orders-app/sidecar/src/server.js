import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { run, poolFor, adminPool, USERS } from './db.js';
import { SEARCHES, parseParams, FUNCTION_SOURCES, RLS_ATTEMPTS } from './endpoints.js';
import { embed, toVectorLiteral, providerName, DIMENSIONS } from './embedding.js';
import * as events from './events.js';

const PORT = Number(process.env.PORT || 5004);
const ALLOWED_ORIGINS = new Set(['http://localhost:5173', 'http://localhost:4173']);

const send = (res, status, body) => {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
};

/** Errore PostgreSQL leggibile, con l'errore originale per il pannello di dettaglio. */
function pgError(err) {
  const friendly = {
    '42501': 'Operazione non consentita dal database (privilegi o policy RLS).',
    '23514': 'Un vincolo del database ha rifiutato l\'operazione.',
    '22P02': 'Valore non valido per il tipo richiesto (JSON, vettore, numero...).',
    '22023': 'Parametro non valido.',
    '42601': 'Query non valida.',
    '57014': 'Operazione interrotta: timeout dell\'istruzione.',
    '54000': 'Limite di PostgreSQL superato (es. payload NOTIFY oltre 8000 byte).',
  }[err.code] ?? 'Errore del database.';
  return { status: err.status ?? (err.code ? 422 : 500), body: { error: { message: err.status ? err.message : friendly, pg: err.code ? { code: err.code, message: err.message, detail: err.detail ?? null } : null } } };
}

function userFrom(req, url) {
  const key = req.headers['x-shop-user'] ?? url.searchParams.get('user');
  if (!USERS[key]) throw Object.assign(new Error('Utente non valido: usare bergamo, milano o manager'), { status: 400 });
  return key;
}

async function readJson(req) {
  let size = 0; const chunks = [];
  for await (const c of req) { size += c.length; if (size > 100_000) throw Object.assign(new Error('Body troppo grande'), { status: 413 }); chunks.push(c); }
  try { return JSON.parse(Buffer.concat(chunks).toString() || '{}'); }
  catch { throw Object.assign(new Error('JSON non valido'), { status: 400 }); }
}

/** Query dei dati + (su richiesta) piano di esecuzione. */
async function handleSearch(name, user, url) {
  const spec = SEARCHES[name];
  let params = parseParams(spec, url.searchParams);
  if (spec.prepare) params = await spec.prepare(params);
  const args = spec.args(params);
  const data = await run(user, spec.sql, args);

  const shown = args.map((a, i) => (spec.hideArgs?.includes(i) ? `<vettore ${DIMENSIONS} dim.>` : a));
  const meta = { feature: spec.feature, role: USERS[user].role, sql: spec.sql, params: shown, ms: data.ms, rows: data.rowCount, function: spec.fn };

  if (url.searchParams.get('plan') === '1' && spec.plan) {
    const p = spec.plan(params);
    const force = url.searchParams.get('force_index') === '1';
    const setup = [...(p.setup ?? []), ...(force ? [['SET LOCAL enable_seqscan = off', []]] : [])];
    const plan = await run(user, `EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON) ${p.sql}`, p.args, { setup });
    meta.plan = { sql: p.sql, forced_index: force, text: plan.rows.map((r) => r['QUERY PLAN']).join('\n').replace(/'\[[-0-9.,e]+\]'/g, `'[… vettore ${DIMENSIONS} dim. …]'`) };
  }
  return { data: data.rows, meta };
}

async function createOrder(user, body) {
  const { customer_id, items, shipping = {}, notes = null } = body;
  if (!Number.isInteger(customer_id)) throw Object.assign(new Error('customer_id mancante o non valido'), { status: 400 });
  if (!Array.isArray(items) || items.length === 0 || items.length > 50) throw Object.assign(new Error('items deve essere un array non vuoto (max 50)'), { status: 400 });
  for (const i of items) {
    if (!Number.isInteger(i.product_id) || !Number.isInteger(i.quantity) || i.quantity < 1 || i.quantity > 1000)
      throw Object.assign(new Error('Ogni riga richiede product_id e quantity interi (1-1000)'), { status: 400 });
  }
  const sql = 'SELECT * FROM shop.create_order($1, $2::jsonb, $3::jsonb, $4)';
  const params = [customer_id, JSON.stringify(items), JSON.stringify(shipping ?? {}), notes];
  const r = await run(user, sql, params);
  return { data: r.rows[0], meta: { feature: 'rls', role: USERS[user].role, sql, params, ms: r.ms, function: 'create_order' } };
}

async function sessionInfo(user) {
  const info = await run(user, `
    SELECT current_user AS db_role, current_setting('app.region', true) AS region,
           (SELECT count(*)::int FROM shop.orders)        AS visible_orders,
           (SELECT count(*)::int FROM shop.customers)     AS visible_customers,
           (SELECT count(*)::int FROM shop.order_events)  AS visible_events,
           (SELECT count(*)::int FROM shop.order_items)   AS visible_items,
           current_setting('statement_timeout') AS statement_timeout`);
  const policies = await run(user, `
    SELECT tablename AS "table", policyname AS name, permissive, cmd, roles::text AS roles, qual AS using, with_check
      FROM pg_policies WHERE schemaname = 'shop' ORDER BY tablename, policyname`);
  const flags = await run(user, `
    SELECT c.relname AS "table", c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced, r.rolname AS owner
      FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'shop' AND c.relkind = 'r' ORDER BY 1`);
  return { data: { session: info.rows[0], policies: policies.rows, tables: flags.rows }, meta: { feature: 'rls', role: USERS[user].role } };
}

async function rlsAttempt(user, key) {
  const a = RLS_ATTEMPTS[key];
  if (!a) throw Object.assign(new Error('Tentativo sconosciuto'), { status: 404 });
  const client = await poolFor(user).connect();
  const t0 = performance.now();
  try {
    await client.query('BEGIN');
    const result = await client.query(a.sql);
    const last = Array.isArray(result) ? result[result.length - 1] : result;
    return { title: a.title, sql: a.sql, ok: true, rowCount: last.rowCount, rows: last.command === 'SELECT' ? last.rows : [], ms: Math.round((performance.now() - t0) * 100) / 100, role: USERS[user].role };
  } catch (err) {
    return { title: a.title, sql: a.sql, ok: false, error: { code: err.code, message: err.message }, role: USERS[user].role };
  } finally {
    await client.query('ROLLBACK').catch(() => {});   // nessun effetto permanente
    client.release();
  }
}

/** Dimostrazioni sulle garanzie di NOTIFY (slide 34-35). Canale dedicato: non sporca il feed ordini. */
async function notifyDemo(kind) {
  const c = await adminPool.connect();
  const tag = (extra = {}) => JSON.stringify({ demo: kind, ...extra });
  try {
    switch (kind) {
      case 'immediate':
        await c.query(`SELECT pg_notify('demo_events', $1)`, [tag()]);
        return 'NOTIFY fuori da una transazione esplicita: consegnata subito al commit implicito.';
      case 'committed':
        await c.query('BEGIN'); await c.query(`SELECT pg_notify('demo_events', $1)`, [tag()]);
        await new Promise((r) => setTimeout(r, 800)); await c.query('COMMIT');
        return 'Notifica emessa dentro una transazione: arriva solo dopo il COMMIT (0,8 s dopo).';
      case 'rolledback':
        await c.query('BEGIN'); await c.query(`SELECT pg_notify('demo_events', $1)`, [tag()]); await c.query('ROLLBACK');
        return 'Transazione annullata: la notifica è scartata e non arriva nessun evento.';
      case 'duplicates':
        await c.query('BEGIN');
        for (let i = 0; i < 3; i++) await c.query(`SELECT pg_notify('demo_events', $1)`, [tag()]);
        await c.query('COMMIT');
        return 'Tre NOTIFY identiche (stesso canale e payload) nella stessa transazione: ne arriva una sola.';
      case 'large':
        await c.query(`SELECT pg_notify('demo_events', $1)`, [tag({ pad: 'x'.repeat(7800) })]);
        return 'Payload di circa 7,9 KB: sotto il limite di 8000 byte, consegnato.';
      case 'toolarge':
        await c.query(`SELECT pg_notify('demo_events', $1)`, [tag({ pad: 'x'.repeat(8100) })]);
        return 'Inatteso: payload oltre 8000 byte accettato.';
      default:
        throw Object.assign(new Error('Tipo di demo sconosciuto'), { status: 404 });
    }
  } finally { c.release(); }
}

async function route(req, res, url) {
  const path = url.pathname;
  if (path === '/api/health') return send(res, 200, { ok: true, embedding: providerName(), dimensions: DIMENSIONS, sse_clients: events.clientCount() });

  if (path === '/api/events') return events.subscribe(req, res, userFrom(req, url));

  if (path.startsWith('/api/search/') && req.method === 'GET') {
    const name = path.slice('/api/search/'.length);
    if (!Object.hasOwn(SEARCHES, name)) return send(res, 404, { error: { message: 'Ricerca sconosciuta' } });
    return send(res, 200, await handleSearch(name, userFrom(req, url), url));
  }

  if (path === '/api/create-order' && req.method === 'POST') return send(res, 201, await createOrder(userFrom(req, url), await readJson(req)));
  if (path === '/api/session' && req.method === 'GET') return send(res, 200, await sessionInfo(userFrom(req, url)));
  if (path.startsWith('/api/rls/try/') && req.method === 'POST') return send(res, 200, await rlsAttempt(userFrom(req, url), path.slice('/api/rls/try/'.length)));
  if (path === '/api/rls/attempts') return send(res, 200, Object.entries(RLS_ATTEMPTS).map(([key, a]) => ({ key, title: a.title, sql: a.sql })));

  if (path.startsWith('/api/notify/demo/') && req.method === 'POST') {
    try { return send(res, 200, { message: await notifyDemo(path.slice('/api/notify/demo/'.length)) }); }
    catch (err) { if (err.code === '54000' || err.code === '22023') return send(res, 200, { message: `PostgreSQL ha rifiutato la NOTIFY: ${err.message}`, rejected: true }); throw err; }
  }
  if (path === '/api/notify/queue') {
    const r = await adminPool.query('SELECT pg_notification_queue_usage() AS usage');
    return send(res, 200, { usage: r.rows[0].usage, sse_clients: events.clientCount() });
  }

  if (path === '/api/source' && req.method === 'GET') {
    const fn = url.searchParams.get('fn');
    if (!FUNCTION_SOURCES.has(fn)) return send(res, 404, { error: { message: 'Funzione non esposta' } });
    const r = await adminPool.query(
      `SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'shop' AND p.proname = $1`, [fn]);
    return send(res, 200, { function: fn, definition: r.rows[0]?.def ?? null });
  }

  if (path === '/api/indexes' && req.method === 'GET') {
    const table = url.searchParams.get('table');
    if (!['products', 'customers', 'orders'].includes(table)) return send(res, 404, { error: { message: 'Tabella non ammessa' } });
    const r = await adminPool.query(
      `SELECT indexname AS name, indexdef AS definition, pg_size_pretty(pg_relation_size(('shop.' || indexname)::regclass)) AS size
         FROM pg_indexes WHERE schemaname = 'shop' AND tablename = $1 ORDER BY indexname`, [table]);
    return send(res, 200, { data: r.rows });
  }

  if (path === '/api/embed' && req.method === 'GET') {
    const q = url.searchParams.get('q') ?? '';
    return send(res, 200, { dimensions: DIMENSIONS, provider: providerName(), embedding: toVectorLiteral(await embed(q.slice(0, 200))) });
  }

  return send(res, 404, { error: { message: 'Endpoint non trovato' } });
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Headers', 'content-type, x-shop-user');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  try {
    await route(req, res, new URL(req.url, 'http://localhost'));
  } catch (err) {
    const { status, body } = pgError(err);
    if (!res.headersSent) send(res, status, body); else res.end();
    if (status >= 500) console.error(err);
  }
});

export { server };
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { bootstrapEmbeddings } = await import('./bootstrap.js');
  server.listen(PORT, () => console.log(`[sidecar] http://localhost:${PORT} · embedding: ${providerName()}`));
  events.start();
  bootstrapEmbeddings().catch((e) => console.error('[bootstrap] embedding non calcolati:', e.message));
}
