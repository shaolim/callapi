require 'webrick'
require 'json'
require 'redis'
require 'logger'
require_relative 'redis_cache'
require_relative 'pricing_service'

class Application
  PORT = 3000

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = ENV.fetch('LOG_LEVEL', 'INFO')
    @logger.formatter = proc { |severity, datetime, _progname, msg| "#{datetime} [#{severity}] #{msg}\n" }

    @server = WEBrick::HTTPServer.new(Port: PORT, Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO))
    redis = Redis.new(url: ENV.fetch('REDIS_URL'))
    cache = RedisCache.new(redis: redis, logger: @logger)
    @pricing_service = PricingService.new(token: ENV.fetch('API_TOKEN'), cache: cache, logger: @logger)

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
