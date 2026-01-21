require 'net/http'
require 'json'
require 'uri'
require 'digest'
require 'logger'
require_relative 'redis_cache'

class PricingService
  DEFAULT_API_URL = ENV.fetch('RATE_API_URL', 'http://rate-api:8080/pricing').freeze
  CACHE_PREFIX = 'pricing:'.freeze
  CACHE_TTL = 300 # 5 minutes

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

    @cache.fetch(cache_key) { fetch_from_api(attributes) }
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

    logger.info { "API request: POST #{uri}" }
    start_time = Time.now

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    duration = ((Time.now - start_time) * 1000).round(2)
    logger.info { "API response: #{response.code} (#{duration}ms)" }

    unless response.is_a?(Net::HTTPSuccess)
      logger.error { "API error: #{response.code} - #{response.body}" }
      raise ApiError.new(response.code, response.body) # rubocop:disable Style/RaiseArgs
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
