require 'webrick'
require 'json'
require 'redis'
require 'logger'
require_relative 'redis_cache'
require_relative 'pricing_service'
require_relative 'leader_follower_cache'
require_relative 'pricing_service_v2'
require_relative 'leader_follower_cache_v2'
require_relative 'pricing_service_v3'

class Application
  PORT = 3000

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = ENV.fetch('LOG_LEVEL', 'INFO')
    @logger.formatter = proc { |severity, datetime, _progname, msg| "#{datetime} [#{severity}] #{msg}\n" }

    @server = WEBrick::HTTPServer.new(Port: PORT, Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO))
    redis = Redis.new(url: ENV.fetch('REDIS_URL'))

    # V1: Simple mutex lock + polling
    cache = RedisCache.new(redis: redis, logger: @logger)
    @pricing_service = PricingService.new(token: ENV.fetch('API_TOKEN'), cache: cache, logger: @logger)

    # V2: Leader-follower with BRPOP + auto-extending lock
    cache_v2 = LeaderFollowerCache.new(redis: redis, logger: @logger)
    @pricing_service_v2 = PricingServiceV2.new(token: ENV.fetch('API_TOKEN'), cache: cache_v2, logger: @logger)

    # V3: Enhanced leader-follower (RECOMMENDED for case requirements)
    #     - Circuit breaker pattern
    #     - Stale cache fallback
    #     - Retry with exponential backoff
    #     - User-friendly timeouts (15s)
    cache_v3 = LeaderFollowerCacheV2.new(redis: redis, logger: @logger)
    @pricing_service_v3 = PricingServiceV3.new(token: ENV.fetch('API_TOKEN'), cache: cache_v3, logger: @logger)

    setup_routes
    setup_signals
  end

  def start
    puts "Server running on http://localhost:#{PORT}"
    @server.start
  end

  private

  def setup_routes
    @server.mount_proc '/health', method(:health_handler)
    @server.mount_proc '/pricing', method(:pricing_handler)
    @server.mount_proc '/pricing/v2', method(:pricing_v2_handler)
    @server.mount_proc '/pricing/v3', method(:pricing_v3_handler)
    @server.mount_proc '/metrics', method(:metrics_handler)
  end

  def setup_signals
    trap('INT') { @server.shutdown }
    trap('TERM') { @server.shutdown }
  end

  def health_handler(_req, res)
    json_response(res, { status: 'ok' })
  end

  def pricing_handler(req, res)
    return method_not_allowed(res) unless req.request_method == 'POST'

    body = JSON.parse(req.body || '{}')
    attributes = body['attributes'] || []
    result = @pricing_service.fetch_pricing(attributes)

    json_response(res, result)
  rescue JSON::ParserError
    error_response(res, 400, 'Invalid JSON')
  rescue PricingService::ApiError => e
    error_response(res, e.code.to_i, e.message)
  rescue StandardError => e
    error_response(res, 500, e.message)
  end

  def pricing_v2_handler(req, res)
    return method_not_allowed(res) unless req.request_method == 'POST'

    body = JSON.parse(req.body || '{}')
    attributes = body['attributes'] || []
    result = @pricing_service_v2.fetch_pricing(attributes)

    json_response(res, result)
  rescue JSON::ParserError
    error_response(res, 400, 'Invalid JSON')
  rescue AsyncRequest::Timeout => e
    error_response(res, 503, "Request timed out: #{e.message}")
  rescue DistributedLock::LockError => e
    error_response(res, 503, "Lock acquisition failed: #{e.message}")
  rescue PricingServiceV2::ApiError => e
    error_response(res, e.code.to_i, e.message)
  rescue StandardError => e
    error_response(res, 500, e.message)
  end

  def pricing_v3_handler(req, res)
    return method_not_allowed(res) unless req.request_method == 'POST'

    body = JSON.parse(req.body || '{}')
    attributes = body['attributes'] || []
    result = @pricing_service_v3.fetch_pricing(attributes)

    json_response(res, result)
  rescue JSON::ParserError
    error_response(res, 400, 'Invalid JSON')
  rescue PricingServiceV3::Error => e
    # User-friendly error messages
    error_response(res, 503, e.message)
  rescue PricingServiceV3::ApiError => e
    error_response(res, e.code.to_i, e.message)
  rescue StandardError => e
    @logger.error { "Unexpected error: #{e.class} - #{e.message}" }
    error_response(res, 500, 'Internal server error')
  end

  def json_response(res, data, status: 200)
    res.status = status
    res['Content-Type'] = 'application/json'
    res.body = data.to_json
  end

  def error_response(res, status, message)
    json_response(res, { error: message }, status: status)
  end

  def method_not_allowed(res)
    error_response(res, 405, 'Method not allowed')
  end
end

Application.new.start
