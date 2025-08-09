import { Umzug, JSONStorage } from 'umzug';
import { Client } from 'pg';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';

async function getClient() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is required');
  const client = new Client({ connectionString: url });
  await client.connect();
  // Session timeouts and lock timeout best practices
  await client.query(`SET lock_timeout = '500ms'; SET statement_timeout = '3s'; SET idle_in_transaction_session_timeout = '5s';`);
  return client;
}

const here = dirname(fileURLToPath(import.meta.url));

const umzug = new Umzug({
  migrations: {
    glob: join(here, '../sql/*.sql'),
    resolve: ({ name, path }) => ({
      name,
      path: path!,
      up: async () => {
        const client = await getClient();
        const sql = await readFile(path!, 'utf8');
        try {
          await client.query('BEGIN');
          await client.query(sql);
          await client.query('COMMIT');
        } catch (e) {
          await client.query('ROLLBACK');
          throw e;
        } finally {
          await client.end();
        }
      },
      down: async () => {
        // no-op for now (forward-only); implement if needed
      }
    })
  },
  storage: new JSONStorage({ path: join(process.cwd(), '.migrations.json') }),
  context: {},
  logger: console
});

async function main() {
  const cmd = process.argv[2] ?? 'status';
  if (cmd === 'up') await umzug.up();
  else if (cmd === 'down') await umzug.down();
  else if (cmd === 'status') {
    const pending = await umzug.pending();
    const executed = await umzug.executed();
    // eslint-disable-next-line no-console
    console.log({ pending: pending.map((m) => m.name), executed: executed.map((m) => m.name) });
  } else {
    throw new Error(`Unknown command: ${cmd}`);
  }
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});


