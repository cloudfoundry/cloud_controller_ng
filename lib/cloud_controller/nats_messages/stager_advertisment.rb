class StagerAdvertisement
  ADVERTISEMENT_EXPIRATION = 10.freeze

  attr_reader :stats

  def initialize(stats)
    @stats = stats
    @updated_at = Time.now
  end

  def stager_id
    stats["id"]
  end

  def expired?
    (Time.now.to_i - @updated_at.to_i) > ADVERTISEMENT_EXPIRATION
  end

  def meets_needs?(mem, stack)
    has_memory?(mem) && has_stack?(stack)
  end

  def memory
    stats["available_memory"]
  end

  def has_memory?(mem)
    memory >= mem
  end

  def has_stack?(stack)
    stats["stacks"].include?(stack)
  end
end