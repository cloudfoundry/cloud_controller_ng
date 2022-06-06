class MinLogRateLimitPolicy
  ERROR_MSG = 'log_rate_limit must be greater than or equal to -1 (where -1 is unlimited)'.freeze

  def initialize(process)
    @process = process
    @errors = process.errors
  end

  def validate
    return unless @process.log_rate_limit

    if @process.log_rate_limit < -1
      @errors.add(:log_rate_limit, ERROR_MSG)
    end
  end
end
