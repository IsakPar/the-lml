-- KEYS: list of seat keys
-- ARGV[1]: sessionId
-- ARGV[2]: version

local sessionId = ARGV[1]
local version = ARGV[2]
local target = version .. ':' .. sessionId
local deleted = 0
for i, k in ipairs(KEYS) do
  local v = redis.call('GET', k)
  if v and v == target then
    redis.call('DEL', k)
    deleted = deleted + 1
  end
end
return deleted


