require 'redis'

redis = Redis.new

# String
puts '- String -'
# Set a value
s = redis.set('user:1:name', 'Alice')
puts "set: #{s}"
# Set a value if not exist
s1 = redis.set('user:1:name', 'Alice', nx: true)
puts "set (nx: true): #{s1}" # nx => not exists
# Get a value
puts redis.get('user:1:name')
# Set with expiration (in seconds)
redis.setex('session:abc123', 3600, 'user_data')
# Set only if key doesn't exist
redis.setnx('lock:process', 'locked')
# Increment/decrement (great for counters)
puts redis.incr('page:views')
puts redis.incr('page:views')
puts redis.decr('page:views')

redis.del('page:views') # clear list

puts '-----'
puts '- Key Management -'

# Keys Management
# Check if key exists
puts redis.exists?('user:1:name')
# Delete a key
redis.del('user:1:name')
# Set expiration on existing key
redis.expire('session:abc123', 1800)
# Get time to live
puts redis.ttl('session:abc123')
# Get all keys matching pattern (use carefully in production!)
puts redis.keys('session:*')

puts '-----'
puts '- Hashes -'

# Hashes
# Set hash fields
redis.hset('user:1', 'name', 'Alice')
redis.hset('user:1', 'email', 'alice@example.com')
# Set multiple fields at once
redis.hmset('user:2', 'name', 'bob', 'email', 'bob@example.com')
# or with ruby 2.4+
redis.mapped_hmset('user:3', name: 'Bob', email: 'bob@example.com')
# get a field
puts redis.hget('user:1', 'name')
# get all fields
puts redis.hgetall('user:1')
# get multiple fields
puts redis.hmget('user:1', 'name', 'email')
# increment a hash field
puts redis.hincrby('user:1', 'login_count', 1)

puts '-----'
puts '- Lists -'

# Lists
# push to the right (end)
redis.rpush('queue:jobs', 'job1')
# => queue:jobs: ['job1']
redis.rpush('queue:jobs', 'job2')
# => queue:jobs: ['job1', 'job2']
# push to the left (beginning)
redis.lpush('queue:jobs', 'urgent_job')
# => queue:jobs: ['urgent_job', 'job1', 'job2']
# pop from the left (FIFO queue)
lpop_result = redis.lpop('queue:jobs') # => 'urgent_job'
puts "lpop_result: #{lpop_result}"
# pop from the right (LIFO stack)
rpop_result = redis.rpop('queue:jobs') # => 'job2'
puts "rpop_result: #{rpop_result}"
# get range of elements
all_items = redis.lrange('queue:jobs', 0, -1)
puts 'all_items:'
p all_items
# get list length
list_length = redis.llen('queue:jobs')
puts "list_length: #{list_length}"
# blocking pop (waits for an item)
blpop = redis.blpop('queue:jobs', timeout: 5) # => ['queue:jobs', 'job1']
puts "blpop: #{blpop}"

redis.del('queue:jobs') # clear list

# Starting with an empty list
redis.rpush('list', 'A')
# List: [A]
redis.rpush('list', 'B')
# List: [A, B]
redis.rpush('list', 'C')
# List: [A, B, C]
# Now use lpush
redis.lpush('list', 'X')
# List: [X, A, B, C]
redis.lpush('list', 'Y')
# List: [Y, X, A, B, C]
redis.del('list') # clear list

# FIFO Queue (Fist In, First Out)
# Use rpush to add + lpop/blpop to remove
# Add jobs to the right
redis.rpush('jobs', 'job1')
redis.rpush('jobs', 'job2')
redis.rpush('jobs', 'job3')
# List: [job1, job2, job3]

# Remove from the left (oldest first)
redis.lpop('jobs')  # => "job1"
redis.lpop('jobs')  # => "job2"
redis.lpop('jobs')  # => "job3"
redis.del('jobs') # clear list

# LIFO Stack (Last In, First Out)
# Use rpush to add + rpop/brpop to remove
# Add to the right
redis.rpush('stack', 'A')
redis.rpush('stack', 'B')
redis.rpush('stack', 'C')
# List: [A, B, C]

# Remove from the right (newest first)
redis.rpop('stack')  # => "C"
redis.rpop('stack')  # => "B"
redis.rpop('stack')  # => "A"
redis.del('stack') # clear list

# Scripting with Lua
# Redis guarantees the script's atomic execution. While executing the script,
# all server activities are blocked during its entire runtime.
# Scripts can employ programmatic control structures and
# use most of the commands while executing to access the database.
# In Lua scripts:
# - KEYS[1], KEYS[2] - access keys array
# - ARGV[1], ARGV[2] - access arguments array
# - redis.call() - call Redis commands
# - return values are automatically converted

RATE_LIMIT_SCRIPT = <<~LUA
  local limit = tonumber(ARGV[1])
  local window = tonumber(ARGV[2])
  local current = redis.call('INCR', KEYS[1])

  if current == 1 then
    redis.call('EXPIRE', KEYS[1], window)
  end

  if current > limit then
    return 0
  else
    return 1
  end
LUA

def rate_limited?(redis, user_id, limit: 100, window: 60)
  key = "rate_limit:#{user_id}"
  result = redis.eval(RATE_LIMIT_SCRIPT, keys: [key], argv: [limit, window])
  result == 1
end

if rate_limited?(redis, '1')
  puts 'allow request'
else
  puts 'reject - too many requests'
end
