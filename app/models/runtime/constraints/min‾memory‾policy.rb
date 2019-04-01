class MinMemoryPolicy
  def initialize(process)
    @process = process
    @errors = process.errors
  end

  def validate
    @errors.add(:memory, :zero_or_less) unless @process.memory > 0
  end
end
