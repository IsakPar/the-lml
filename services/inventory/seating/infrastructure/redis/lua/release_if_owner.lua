-- KEYS: list of seat keys
-- ARGV[1]: sessionId

local sessionId = ARGV[1]
local deleted = 0
for i, k in ipairs(KEYS) do
  local v = redis.call('GET', k)
  if v and string.sub(v, -string.len(sessionId)) == sessionId then
    redis.call('DEL', k)
    deleted = deleted + 1
  end
end
return deleted



