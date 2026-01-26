require 'net/http'
require 'json'
require 'uri'
require 'digest'
require 'logger'
require_relative 'leader_follower_cache_v2'

# PricingService V3 using enhanced Leader-Follower pattern
# Optimized for the Tripla case requirements:
# - Handles expensive API operations (auto-extending lock)
# - Respects rate limits (circuit breaker, no duplicate calls)
# - Graceful degradation (stale cache fallback)
# - User-friendly timeouts (15s instead of 55s)
# - Production-ready error handling
class PricingServiceV3
  DEFAULT_API_URL = ENV.fetch('RATE_API_URL', 'http://rate-api:8080/pricing').freeze
  CACHE_PREFIX = 'pricing:v3:'.freeze
  CACHE_TTL = 300 # 5 minutes (per case requirements)

  class Error < StandardError; end

  class ApiError < Error
    attr_reader :code

    def initialize(code, message)
      @code = code
      super("API error #{code}: #{message}")
    end
  end

  def initialize(token:, cache:, logger: nil, api_url: DEFAULT_API_URL)
    @uri = URI(api_url)
    @token = token
    @cache = cache
    @logger = logger || Logger.new(IO::NULL)
  end

  def fetch_pricing(attributes)
    return [] unless attributes.is_a?(Array) && attributes.any?

    cache_key = build_cache_key(attributes)

    @cache.fetch(cache_key) do
      fetch_from_api(attributes)
    end
  rescue AsyncRequest::Timeout => e
    @logger.error { "[V3] Follower timeout: #{e.message}" }
    raise Error, 'Price calculation timed out. The service is experiencing high load. Please retry in a few seconds.'
  rescue DistributedLock::LockError => e
    @logger.error { "[V3] Lock error: #{e.message}" }
    raise Error, 'Unable to coordinate price calculation. Please retry.'
  rescue CircuitBreaker::CircuitBreakerError => e
    @logger.error { "[V3] Circuit breaker open: #{e.message}" }
    raise Error, 'Pricing service is temporarily unavailable. Returning cached data if available.'
  rescue StandardError => e
    @logger.error { "[V3] Unexpected error: #{e.class} - #{e.message}" }
    raise Error, 'An unexpected error occurred. Please try again.'
  end

  # Reset circuit breaker (for manual intervention)
  def reset_circuit_breaker
    @cache.reset_circuit_breaker
  end

  private

  attr_reader :uri, :token, :logger

  def build_cache_key(attributes)
    normalized = attributes.map { |a| normalize_attr(a) }.sort_by { |a| a.values.join }
    hash = Digest::SHA256.hexdigest(normalized.to_json)
    "#{CACHE_PREFIX}#{hash}"
  end

  def fetch_from_api(attributes)
    request = build_request(attributes)

    logger.info { "[V3] API request: POST #{uri}" }

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      logger.error { "[V3] API error: #{response.code} - #{response.body}" }
      raise ApiError.new(response.code, response.body)
    end

    JSON.parse(response.body)
  end

  def build_request(attributes)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request['token'] = token
    request.body = { attributes: attributes.map { |a| normalize_attr(a) } }.to_json
    request
  end

  def normalize_attr(raw)
    {
      period: raw[:period] || raw['period'],
      hotel: raw[:hotel] || raw['hotel'],
      room: raw[:room] || raw['room']
    }.compact
  end
end
