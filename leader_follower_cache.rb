require 'json'
require 'logger'
require_relative 'distributed_lock'
require_relative 'async_request'

class LeaderFollowerCache
  DEFAULT_TTL = 300 # 5 minutes
  FOLLOWER_TIMEOUT = 55 # seconds (shorter than lock TTL)

  def initialize(redis:, logger: nil, ttl: DEFAULT_TTL)
    @redis = redis
    @logger = logger || Logger.new(IO::NULL)
    @ttl = ttl
  end

  # Fetch with leader-follower coordination
  # Only one request (leader) executes the block
  # Other requests (followers) wait for leader's result
  def fetch(key, &block)
    # Check cache first
    cached = get(key)
    return cached if cached

    # Try to become leader
    lock = DistributedLock.new(@redis, lock_key(key))

    begin
      # Try to acquire lock and become leader
      @logger.info { "Attempting to become leader for key: #{key}" }

      lock.with_lock do
        # Double-check cache after acquiring lock
        cached = get(key)
        return cached if cached

        @logger.info { "Became leader for key: #{key}" }

        # Execute expensive operation
        result = block.call

        # Cache the result
        set(key, result)

        # Publish to all waiting followers
        publish_to_followers(key, result)

        result
      end
    rescue DistributedLock::LockError
      # Failed to acquire lock, become follower
      @logger.info { "Became follower for key: #{key}" }
      execute_as_follower(key)
    end
  end

  def get(key)
    data = @redis.get(key)
    return nil unless data

    @logger.info { "Cache hit: #{key}" }
    JSON.parse(data)
  rescue JSON::ParserError => e
    @logger.error { "Invalid JSON in cache for key #{key}: #{e.message}" }
    nil
  end

  def set(key, value, ttl: @ttl)
    @redis.set(key, value.to_json, ex: ttl)
    @logger.info { "Cached for #{ttl}s: #{key}" }
  end

  def delete(key)
    @redis.del(key)
  end

  private

  def lock_key(key)
    "lock:#{key}"
  end

  def execute_as_follower(key)
    # Register and wait for leader's result
    request = AsyncRequest.create(key, timeout: FOLLOWER_TIMEOUT, redis: @redis)

    @logger.info { "Follower waiting for result: #{key}" }
    result = request.wait!

    @logger.info { "Follower received result: #{key}" }
    result
  rescue AsyncRequest::Timeout => e
    @logger.error { "Follower timeout for key #{key}: #{e.message}" }
    raise
  end

  def publish_to_followers(key, result)
    result_payload = result.to_json

    while (waiter_queue = @redis.rpop("waiters:#{key}"))
      @redis.lpush(waiter_queue, result_payload)
    end
  ensure
    # Cleanup waiter list
    @redis.del("waiters:#{key}")
  end
end
