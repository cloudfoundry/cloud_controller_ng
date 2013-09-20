class DeaAdvertisement
  ADVERTISEMENT_EXPIRATION = 10.freeze

  attr_reader :stats

  def initialize(stats)
    @stats = stats
    @updated_at = Time.now
  end

  def increment_instance_count(app_id)
    stats["app_id_to_count"][app_id] = num_instances_of(app_id) + 1
  end

  def num_instances_of(app_id)
    stats["app_id_to_count"].fetch(app_id, 0)
  end

  def available_memory
    stats["available_memory"]
  end

  def dea_id
    stats["id"]
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