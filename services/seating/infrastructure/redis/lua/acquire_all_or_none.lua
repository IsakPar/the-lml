-- KEYS: list of seat keys
-- ARGV[1]: sessionId
-- ARGV[2]: version
-- ARGV[3]: ttlMs

local sessionId = ARGV[1]
local version = ARGV[2]
local ttl = tonumber(ARGV[3])

-- Check for conflicts
for i, k in ipairs(KEYS) do
  local v = redis.call('GET', k)
  if v and string.sub(v, -string.len(sessionId)) ~= sessionId then
    return {err = 'CONFLICT'}
  end
end

-- Set all keys
local val = version .. ':' .. sessionId
for i, k in ipairs(KEYS) do
  redis.call('SET', k, val, 'PX', ttl)
end
return 'OK'



