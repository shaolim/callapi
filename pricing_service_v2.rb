require 'net/http'
require 'json'
require 'uri'
require 'digest'
require 'logger'
require_relative 'leader_follower_cache'

# PricingService V2 using Leader-Follower pattern
# Comparison with V1:
# - V1 (RedisCache): Mutex lock + polling, max 10s operations
# - V2 (LeaderFollowerCache): Leader election + BRPOP, supports long operations
class PricingServiceV2
  DEFAULT_API_URL = ENV.fetch('RATE_API_URL', 'http://rate-api:8080/pricing').freeze
  CACHE_PREFIX = 'pricing:v2:'.freeze
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

    @logger.info { "[V2] Fetching pricing for key: #{cache_key}" }

    @cache.fetch(cache_key) do
      @logger.info { '[V2] Leader executing API request' }
      fetch_from_api(attributes)
    end
  rescue AsyncRequest::Timeout => e
    @logger.error { "[V2] Follower timeout: #{e.message}" }
    raise Error, 'Price calculation timed out. Please retry.'
  rescue DistributedLock::LockError => e
    @logger.error { "[V2] Lock error: #{e.message}" }
    raise Error, 'Unable to coordinate price calculation. Please retry.'
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

    logger.info { "[V2] API request: POST #{uri}" }
    start_time = Time.now

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    duration = ((Time.now - start_time) * 1000).round(2)
    logger.info { "[V2] API response: #{response.code} (#{duration}ms)" }

    unless response.is_a?(Net::HTTPSuccess)
      logger.error { "[V2] API error: #{response.code} - #{response.body}" }
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
