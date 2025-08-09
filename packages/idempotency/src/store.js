// Stub metrics to avoid import issues
const metrics = {
    idem_begin_total: { inc: () => {} },
    idem_hit_cached_total: { inc: () => {} },
    idem_begin_conflict_total: { inc: () => {} },
    idem_commit_total: { inc: () => {} }
};

export function createIdemStore(client) {
    console.log(`🌟 CREATING IDEM STORE AT ${new Date().toISOString()}`);
    return {
        async get(key) {
            const v = await client.get(key);
            return v ? JSON.parse(v) : { state: 'missing' };
        },
        async begin(key, ownerRequestId, ttlSec) {
            console.log(`🔥 STORE BEGIN CALLED: ${key}`);
            metrics.idem_begin_total.inc();
            
            // Try to create a pending record
            const pending = { state: 'in-progress', ownerRequestId, startedAt: Date.now() };
            const ok = await client.set(key, JSON.stringify(pending), 'EX', ttlSec, 'NX');
            console.log(`🔥 Redis SET result: ${JSON.stringify(ok)} for key ${key}`);
            
            if (ok === 'OK') {
                // Successfully created new key - this is the first request
                console.log(`🔥 NEW KEY CREATED - returning state=new`);
                return { state: 'new', ownerRequestId, startedAt: Date.now() };
            }
            
            // Key already exists - check what state it's in
            console.log(`🔥 KEY EXISTS - fetching current state`);
            const existing = await this.get(key);
            console.log(`🔥 EXISTING STATE: ${JSON.stringify(existing)}`);
            
            if (existing.state === 'committed') {
                metrics.idem_hit_cached_total.inc();
            } else if (existing.state === 'in-progress') {
                metrics.idem_begin_conflict_total.inc();
            }
            
            return existing;
        },
        async commit(key, meta, ttlSec) {
            const committed = { 
                state: 'committed', 
                status: meta.status, 
                headersHash: meta.headersHash, 
                bodyHash: meta.bodyHash, 
                createdAt: Date.now() 
            };
            await client.set(key, JSON.stringify(committed), 'EX', ttlSec, 'XX');
            metrics.idem_commit_total.inc();
        }
    };
}