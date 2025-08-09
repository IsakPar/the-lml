-- KEYS[1]: seat key
-- ARGV: owner, version, ttl_ms, now_ms
-- Returns: "OK" | "NOOP"

local owner = ARGV[1]
local version = tostring(ARGV[2])
local ttl_ms = tonumber(ARGV[3])

local v = redis.call('GET', KEYS[1])
if not v then return 'NOOP' end
local sep = string.find(v, ':', 1, true)
if not sep then return 'NOOP' end
local v_version = string.sub(v, 1, sep - 1)
local v_owner = string.sub(v, sep + 1)
if v_owner ~= owner then return 'NOOP' end
if v_version ~= version then return 'NOOP' end
redis.call('PEXPIRE', KEYS[1], ttl_ms)
return 'OK'

-- extend_if_owner: extend TTL only if owner+version match
-- Returns: OK or NOOP
-- metrics: acquire_ok, acquire_conflict, extend_ok, release_ok, rollback_ok, lua_error
