class Advertisement
  ADVERTISEMENT_EXPIRATION = 10.freeze

  attr_reader :stats

  def initialize(stats)
    @stats = stats
    @updated_at = Time.now
  end

  def id
    stats["id"]
  end

  def available_memory
    stats["available_memory"]
  end

  def decrement_memory(mem)
    stats["available_memory"] -= mem
  end

  def available_disk
    stats["available_disk"]
  end

  def decrement_disk(disk)
    stats["available_disk"] -= disk if stats["available_disk"]
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

  def has_sufficient_disk?(disk)
    return true unless available_disk
    available_disk >= disk
  end

  def zone
    stats.fetch("placement_properties", {}).fetch("zone", "default")
  end

  def num_instances_of(app_id)
    stats["app_id_to_count"].fetch(app_id, 0)
  end

  def num_instances_of_all
    stats["app_id_to_count"].inject(0) { |sum, app_count| sum + app_count[1] }
  end

  def clear_app_id_to_count(app_id)
    stats["app_id_to_count"].delete(app_id)
  end
end
