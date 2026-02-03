require 'json'

class RedisCache
  DEFAULT_TTL = 300 # 5 minutes
  LOCK_TTL = 10 # seconds
  LOCK_RETRY_DELAY = 0.1 # 100ms
  LOCK_MAX_RETRIES = 50 # 5 seconds max wait

  def initialize(redis:, logger: nil, ttl: DEFAULT_TTL)
    @redis = redis
    @logger = logger || Logger.new(IO::NULL)
    @ttl = ttl
  end

  def fetch(key, &)
    cached = get(key)
    return cached if cached

    fetch_with_lock(key, &)
  end

  def get(key)
    data = @redis.get(key)
    return nil unless data

    @logger.debug { "Cache hit: #{key}" }
    JSON.parse(data)
  end

  def set(key, value, ttl: @ttl)
    @redis.set(key, value.to_json, ex: ttl)
    @logger.debug { "Cached for #{ttl}s: #{key}" }
  end

  def delete(key)
    @redis.del(key)
  end

  private

  def fetch_with_lock(key, &)
    lock_key = "lock:#{key}"

    if acquire_lock(lock_key)
      begin
        # Double-check cache after acquiring lock
        cached = get(key)
        return cached if cached

        @logger.info { "Cache miss: #{key}" }
        data = yield

        set(key, data)
        data
      ensure
        release_lock(lock_key)
      end
    else
      wait_for_cache(key, &)
    end
  end

  def acquire_lock(lock_key)
    acquired = @redis.set(lock_key, Time.now.to_i, nx: true, ex: LOCK_TTL)
    @logger.debug { "Lock #{acquired ? 'acquired' : 'not acquired'}: #{lock_key}" }
    acquired
  end

  def release_lock(lock_key)
    @redis.del(lock_key)
    @logger.debug { "Lock released: #{lock_key}" }
  end

  def wait_for_cache(key)
    @logger.debug { 'Waiting for another request to populate cache...' }

    LOCK_MAX_RETRIES.times do
      sleep(LOCK_RETRY_DELAY)

      cached = get(key)
      return cached if cached
    end

    @logger.warn { 'Timeout waiting for cache, fetching directly' }
    yield
  end
end
