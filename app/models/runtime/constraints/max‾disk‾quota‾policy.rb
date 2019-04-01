class MaxDiskQuotaPolicy
  ERROR_MSG = 'too much disk requested (requested %<desired>s MB - must be less than %<max>s MB)'.freeze

  def initialize(process, max_mb)
    @process = process
    @errors = process.errors
    @max_mb = max_mb
  end

  def validate
    return unless @process.disk_quota

    if @process.disk_quota > @max_mb
      @errors.add(:disk_quota, sprintf(ERROR_MSG, desired: @process.disk_quota, max: @max_mb))
    end
  end
end
