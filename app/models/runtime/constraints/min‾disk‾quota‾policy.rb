class MinDiskQuotaPolicy
  ERROR_MSG = 'too little disk requested (must be greater than zero)'.freeze

  def initialize(process)
    @process = process
    @errors = process.errors
  end

  def validate
    return unless @process.disk_quota

    if @process.disk_quota < 1
      @errors.add(:disk_quota, ERROR_MSG)
    end
  end
end
