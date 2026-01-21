require 'net/http'
require 'json'
require 'uri'
require 'digest'
require 'logger'

class PricingService
  DEFAULT_API_URL = ENV.fetch('RATE_API_URL', 'http://rate-api:8080/pricing').freeze
  CACHE_TTL = 300 # 5 minutes in seconds
  CACHE_PREFIX = 'pricing:'.freeze

  class Error < StandardError; end

  class ApiError < Error
    attr_reader :code

    def initialize(code, message)
      @code = code
      super("API error #{code}: #{message}")
    end
  end

  def initialize(token:, redis:, logger: nil, api_url: DEFAULT_API_URL)
    @uri = URI(api_url)
    @token = token
    @redis = redis
    @logger = logger || Logger.new(IO::NULL)
  end

  def fetch_pricing(attributes)
    return [] unless attributes.is_a?(Array) && attributes.any?

    cache_key = build_cache_key(attributes)

    cached = @redis.get(cache_key)
    if cached
      @logger.info { "Cache hit: #{cache_key}" }
      return JSON.parse(cached)
    end

    @logger.info { "Cache miss: #{cache_key}" }
    response = make_request(attributes)
    data = JSON.parse(response.body)

    @redis.set(cache_key, data.to_json, ex: CACHE_TTL)
    @logger.info { "Cached response for #{CACHE_TTL}s" }

    data
  end

  private

  attr_reader :uri, :token, :logger

  def build_cache_key(attributes)
    normalized = attributes.map { |a| normalize_attr(a) }.sort_by { |a| a.values.join }
    hash = Digest::SHA256.hexdigest(normalized.to_json)
    "#{CACHE_PREFIX}#{hash}"
  end

  def make_request(attributes)
    request = build_request(attributes)

    logger.info { "API request: POST #{uri}" }
    start_time = Time.now

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    duration = ((Time.now - start_time) * 1000).round(2)
    logger.info { "API response: #{response.code} (#{duration}ms)" }

    unless response.is_a?(Net::HTTPSuccess)
      logger.error { "API error: #{response.code} - #{response.body}" }
      raise ApiError.new(response.code, response.body)
    end

    response
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
