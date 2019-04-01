class InstancesPolicy
  def initialize(process)
    @process = process
    @errors = process.errors
  end

  def validate
    if @process.instances < 0
      @errors.add(:instances, :less_than_zero)
    end
  end
end
