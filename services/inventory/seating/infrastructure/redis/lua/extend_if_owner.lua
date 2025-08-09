-- KEYS: list of seat keys
-- ARGV[1]: sessionId
-- ARGV[2]: ttlMs

local sessionId = ARGV[1]
local ttl = tonumber(ARGV[2])
local updated = 0
for i, k in ipairs(KEYS) do
  local v = redis.call('GET', k)
  if v and string.sub(v, -string.len(sessionId)) == sessionId then
    redis.call('PEXPIRE', k, ttl)
    updated = updated + 1
  end
end
return updated



