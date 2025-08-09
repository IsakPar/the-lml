-- acquire_seat_locks.lua
-- Atomically acquire multiple seat locks with fencing tokens
-- 
-- KEYS[1]: prefix for seat locks (e.g., "seat:lock:")
-- KEYS[2]: user locks key (e.g., "user:locks:{user_id}")
-- ARGV[1]: JSON array of seat IDs
-- ARGV[2]: user_id
-- ARGV[3]: session_id (optional)
-- ARGV[4]: ttl_seconds
-- ARGV[5]: max_extensions
-- ARGV[6]: master_fencing_token
-- ARGV[7]: current_timestamp (ISO string)

local seat_lock_prefix = KEYS[1]
local user_locks_key = KEYS[2]

local seat_ids = cjson.decode(ARGV[1])
local user_id = ARGV[2]
local session_id = ARGV[3]
local ttl = tonumber(ARGV[4])
local max_extensions = tonumber(ARGV[5])
local master_fencing_token = ARGV[6]
local current_timestamp = ARGV[7]

-- Result containers
local acquired_locks = {}
local failed_seats = {}
local queued_seats = {}

-- First pass: Check availability of all seats
local available_seats = {}
local unavailable_seats = {}

for i, seat_id in ipairs(seat_ids) do
    local seat_key = seat_lock_prefix .. seat_id
    local existing_lock = redis.call('GET', seat_key)
    
    if existing_lock then
        local lock_data = cjson.decode(existing_lock)
        
        -- Check if user already owns this lock
        if lock_data.user_id == user_id then
            -- User already has this seat locked
            table.insert(acquired_locks, {
                seat_id = seat_id,
                user_id = user_id,
                session_id = session_id,
                fencing_token = lock_data.fencing_token,
                acquired_at = lock_data.acquired_at,
                expires_at = lock_data.expires_at,
                extension_count = lock_data.extension_count,
                max_extensions = lock_data.max_extensions
            })
        else
            -- Seat is locked by someone else
            table.insert(failed_seats, {
                seat_id = seat_id,
                reason = "already_locked",
                locked_by = lock_data.user_id,
                locked_until = lock_data.expires_at
            })
            table.insert(unavailable_seats, seat_id)
        end
    else
        -- Seat is available
        table.insert(available_seats, seat_id)
    end
end

-- Second pass: Atomically acquire all available seats
-- If we can't get all requested seats, we'll still acquire what we can
for i, seat_id in ipairs(available_seats) do
    local seat_key = seat_lock_prefix .. seat_id
    local individual_fencing_token = master_fencing_token .. ":" .. seat_id
    
    local lock_data = {
        user_id = user_id,
        session_id = session_id,
        fencing_token = individual_fencing_token,
        acquired_at = current_timestamp,
        expires_at = current_timestamp, -- Will be calculated on client side
        extension_count = 0,
        max_extensions = max_extensions
    }
    
    -- Use SET with NX to ensure atomicity
    local result = redis.call('SET', seat_key, cjson.encode(lock_data), 'EX', ttl, 'NX')
    
    if result == 'OK' then
        -- Successfully acquired lock
        table.insert(acquired_locks, lock_data)
        
        -- Add to user's lock inventory
        redis.call('SADD', user_locks_key, seat_id)
        redis.call('EXPIRE', user_locks_key, ttl + 60) -- Slightly longer TTL for cleanup
        
    else
        -- Another process acquired it between our checks
        table.insert(failed_seats, {
            seat_id = seat_id,
            reason = "race_condition",
            message = "Seat was acquired by another user"
        })
    end
end

-- Update metrics (if keys exist)
local metrics_key = "metrics:seat_locks:" .. string.sub(current_timestamp, 1, 13) -- Minute-level metrics
if #acquired_locks > 0 then
    redis.call('HINCRBY', metrics_key, 'locks_acquired', #acquired_locks)
    redis.call('EXPIRE', metrics_key, 3600) -- 1 hour retention
end

if #failed_seats > 0 then
    redis.call('HINCRBY', metrics_key, 'locks_failed', #failed_seats)
end

-- Return comprehensive result
return cjson.encode({
    acquired_locks = acquired_locks,
    failed_seats = failed_seats,
    queued_seats = queued_seats, -- Empty for now, can be extended
    master_fencing_token = master_fencing_token,
    total_requested = #seat_ids,
    total_acquired = #acquired_locks,
    total_failed = #failed_seats,
    timestamp = current_timestamp
})
