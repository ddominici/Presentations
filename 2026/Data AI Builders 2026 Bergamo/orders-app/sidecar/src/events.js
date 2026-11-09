// LISTEN/NOTIFY -> Server-Sent Events.
// Una connessione DEDICATA, fuori dal pool, tenuta aperta per tutta la vita del processo:
// la registrazione LISTEN vale per la sessione e si annulla alla sua chiusura.
import { newAdminClient } from './db.js';

const CHANNELS = ['order_events', 'demo_events'];
const clients = new Set();   // { res, user, region }

let listener = null;
let retryTimer = null;

const regionOf = (user) => (user === 'manager' ? '*' : user);

function broadcast(event, data, region) {
  const frame = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const c of clients) {
    // NB: filtro per comodità della UI, NON un confine di sicurezza: il confine è la RLS sulle API di lettura.
    // Il payload contiene solo chiave e stato; i dati completi si rileggono con il ruolo dell'utente.
    if (!region || c.region === '*' || c.region === region) c.res.write(frame);
  }
}

async function connect() {
  const client = newAdminClient();
  listener = client;
  client.on('notification', (msg) => {
    let payload;
    try { payload = JSON.parse(msg.payload); } catch { payload = { raw: msg.payload }; }
    broadcast('notify', {
      channel: msg.channel, pid: msg.processId, payload, received_at: new Date().toISOString(),
    }, payload.region);
  });
  const reconnect = (why) => {
    if (listener !== client) return;
    listener = null;
    console.error('[events] connessione LISTEN persa:', why);
    client.end().catch(() => {});
    clearTimeout(retryTimer);
    retryTimer = setTimeout(start, 2000);
  };
  client.on('error', (e) => reconnect(e.message));
  client.on('end', () => reconnect('end'));
  await client.connect();
  for (const ch of CHANNELS) await client.query(`LISTEN ${ch}`);   // nomi canale costanti, non da input
  console.log('[events] in ascolto su', CHANNELS.join(', '));
  // Dopo una riconnessione si potrebbero aver perso notifiche: i client rileggono lo stato corrente.
  broadcast('resync', { at: new Date().toISOString() });
}

export function start() {
  connect().catch((e) => {
    console.error('[events] avvio fallito:', e.message);
    clearTimeout(retryTimer);
    retryTimer = setTimeout(start, 2000);
  });
}

export function subscribe(req, res, user) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.write(`retry: 2000\n\n`);
  const client = { res, user, region: regionOf(user) };
  clients.add(client);
  res.write(`event: ready\ndata: ${JSON.stringify({ user, listening: Boolean(listener) })}\n\n`);
  const ping = setInterval(() => res.write(': ping\n\n'), 20000);
  req.on('close', () => { clearInterval(ping); clients.delete(client); });
}

export const clientCount = () => clients.size;
