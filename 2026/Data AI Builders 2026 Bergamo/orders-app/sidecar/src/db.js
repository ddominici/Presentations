import pg from 'pg';

// numeric/int8 come numeri JSON (come fa Data API Builder), non come stringhe
pg.types.setTypeParser(1700, (v) => parseFloat(v));
pg.types.setTypeParser(20, (v) => parseInt(v, 10));

const env = process.env;

/** Utente di demo -> ruolo di database. La RLS si basa sul ruolo con cui ci si collega. */
export const USERS = {
  bergamo: { role: 'rep_bergamo', label: 'Venditore Bergamo' },
  milano: { role: 'rep_milano', label: 'Venditore Milano' },
  manager: { role: 'shop_manager', label: 'Manager (tutte le regioni)' },
};

function connectionString(user, password) {
  if (env.DATABASE_URL) {
    const u = new URL(env.DATABASE_URL);
    u.username = user;
    u.password = password;
    return u.toString();
  }
  return `postgres://${user}:${password}@${env.PGHOST || 'localhost'}:${env.PGPORT || 15440}/${env.PGDATABASE || 'shop'}`;
}

const appPassword = env.APP_ROLE_PASSWORD || 'demo_only';
const pools = new Map();

export function poolFor(userKey) {
  const user = USERS[userKey];
  if (!user) return null;
  if (!pools.has(userKey)) {
    pools.set(userKey, new pg.Pool({
      connectionString: connectionString(user.role, appPassword), max: 4, idleTimeoutMillis: 30000,
    }));
  }
  return pools.get(userKey);
}

/** Connessione amministrativa: solo per il bootstrap degli embedding e per i demo NOTIFY. */
const adminUrl = () => env.DATABASE_URL ?? connectionString('postgres', env.POSTGRES_PASSWORD || 'postgres');
export const adminPool = new pg.Pool({ connectionString: adminUrl(), max: 3 });
export const newAdminClient = () => new pg.Client({ connectionString: adminUrl() });

/**
 * Esegue una query in transazione con il ruolo dell'utente scelto e misura il tempo.
 * `setup` sono istruzioni parametrizzate eseguite prima (es. soglie, enable_seqscan).
 */
export async function run(userKey, sql, params = [], { setup = [], rollback = false } = {}) {
  const pool = poolFor(userKey);
  if (!pool) throw Object.assign(new Error('Utente non valido'), { status: 400 });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const [s, p] of setup) await client.query(s, p);
    const t0 = performance.now();
    const result = await client.query(sql, params);
    const ms = performance.now() - t0;
    await client.query(rollback ? 'ROLLBACK' : 'COMMIT');
    return { rows: result.rows, rowCount: result.rowCount, ms: Math.round(ms * 100) / 100 };
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}
