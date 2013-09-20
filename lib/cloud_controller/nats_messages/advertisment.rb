class Advertisement
  ADVERTISEMENT_EXPIRATION = 10.freeze

  attr_reader :stats

  def initialize(stats)
    @stats = stats
    @updated_at = Time.now
  end

  def available_memory
    stats["available_memory"]
  end

  def expired?
    (Time.now.to_i - @updated_at.to_i) > ADVERTISEMENT_EXPIRATION
  end

  def meets_needs?(mem, stack)
    has_sufficient_memory?(mem) && has_stack?(stack)
  end

  def has_stack?(stack)
    stats["stacks"].include?(stack)
  end

  def has_sufficient_memory?(mem)
    available_memory >= mem
  end
end