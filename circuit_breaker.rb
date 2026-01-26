# Circuit Breaker pattern to prevent cascade failures
# Opens circuit after threshold failures, preventing further attempts
class CircuitBreaker
  attr_reader :failure_count, :last_failure_time, :state

  STATES = {
    closed: :closed,     # Normal operation
    open: :open,         # Failing, reject requests
    half_open: :half_open # Testing if service recovered
  }.freeze

  def initialize(threshold: 5, timeout: 60, logger: nil)
    @threshold = threshold
    @timeout = timeout
    @logger = logger || Logger.new(IO::NULL)
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
  end

  def call
    case @state
    when :open
      if time_to_retry?
        @logger.info { 'Circuit breaker: Transitioning to half-open' }
        @state = :half_open
      else
        @logger.warn { 'Circuit breaker: Circuit is open, rejecting request' }
        raise CircuitBreakerError, 'Circuit breaker is open'
      end
    end

    begin
      result = yield
      record_success
      result
    rescue StandardError
      record_failure
      raise
    end
  end

  def open?
    @state == :open
  end

  def closed?
    @state == :closed
  end

  def half_open?
    @state == :half_open
  end

  def record_success
    @failure_count = 0
    @state = :closed
    @logger.info { 'Circuit breaker: Success recorded, circuit closed' }
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = Time.now

    if @failure_count >= @threshold
      @state = :open
      @logger.error { "Circuit breaker: Threshold reached (#{@failure_count}), opening circuit" }
    else
      @logger.warn { "Circuit breaker: Failure #{@failure_count}/#{@threshold}" }
    end
  end

  def reset
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
    @logger.info { 'Circuit breaker: Manually reset' }
  end

  private

  def time_to_retry?
    return false unless @last_failure_time

    Time.now - @last_failure_time >= @timeout
  end

  class CircuitBreakerError < StandardError; end
end
