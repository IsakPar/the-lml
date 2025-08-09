--
-- KEYS: seat keys (one per seat)
-- ARGV: owner, version, ttl_ms, now_ms
-- Returns: "OK" | {"CONFLICT", key1, key2, ...}

local owner = ARGV[1]
local version = ARGV[2]
local ttl_ms = tonumber(ARGV[3])
local now_ms = tonumber(ARGV[4])

local conflicts = {}
for i, k in ipairs(KEYS) do
  local v = redis.call('GET', k)
  if v and not string.find(v, ':' .. owner .. '$') then
    table.insert(conflicts, k)
  end
end

if #conflicts > 0 then
  local resp = {'CONFLICT'}
  for i, k in ipairs(conflicts) do table.insert(resp, k) end
  return resp
end

for i, k in ipairs(KEYS) do
  redis.call('PSETEX', k, ttl_ms, version .. ':' .. owner)
end

return 'OK'

-- acquire_all_or_none: fail with list of conflicts or set all with owner/version/TTL
-- Returns: OK or { conflictKeys: string[] }
-- metrics: acquire_ok, acquire_conflict, extend_ok, release_ok, rollback_ok, lua_error
