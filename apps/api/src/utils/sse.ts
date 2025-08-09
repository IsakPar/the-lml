import type { ServerResponse } from 'node:http';

const clients = new Set<ServerResponse>();

export function addClient(res: ServerResponse) {
  clients.add(res);
}

export function removeClient(res: ServerResponse) {
  clients.delete(res);
}

export function broadcast(event: string, data: unknown) {
  const payload = `event: ${event}\n` + `data: ${JSON.stringify(data)}\n\n`;
  for (const c of clients) {
    try { c.write(payload); } catch {}
  }
}


