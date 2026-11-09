// Calcola (una volta sola) gli embedding dei prodotti che ne sono privi e li salva in pgvector.
import { adminPool } from './db.js';
import { embed, toVectorLiteral, providerName } from './embedding.js';

const productText = (p) => [p.name, p.description, p.category, Object.entries(p.attributes ?? {}).map(([k, v]) => `${k} ${Array.isArray(v) ? v.join(' ') : v}`).join(' ')].join('. ');

export async function bootstrapEmbeddings() {
  for (let attempt = 0; ; attempt++) {
    try { await adminPool.query('SELECT 1'); break; }
    catch (e) { if (attempt > 30) throw e; await new Promise((r) => setTimeout(r, 2000)); }
  }
  const { rows } = await adminPool.query('SELECT id, name, description, category, attributes FROM shop.products WHERE embedding IS NULL ORDER BY id');
  if (rows.length === 0) { console.log('[bootstrap] embedding già presenti'); return; }
  console.log(`[bootstrap] calcolo ${rows.length} embedding con ${providerName()}`);
  for (const p of rows) {
    const vec = toVectorLiteral(await embed(productText(p)));
    await adminPool.query('UPDATE shop.products SET embedding = $1::vector WHERE id = $2', [vec, p.id]);
  }
  await adminPool.query('ANALYZE shop.products');
  console.log('[bootstrap] embedding salvati');
}
