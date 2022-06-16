class MinLogQuotaPolicy
  ERROR_MSG = 'log_quota must be greater than or equal to -1 (where -1 is unlimited)'.freeze

  def initialize(process)
    @process = process
    @errors = process.errors
  end

  def validate
    return unless @process.log_quota

    if @process.log_quota < -1
      @errors.add(:log_quota, ERROR_MSG)
    end
  end
end
