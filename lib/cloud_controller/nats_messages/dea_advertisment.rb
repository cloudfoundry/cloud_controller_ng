require "cloud_controller/nats_messages/advertisment"

class DeaAdvertisement < Advertisement
  def dea_id
    stats["id"]
  end

  def increment_instance_count(app_id)
    stats["app_id_to_count"][app_id] = num_instances_of(app_id) + 1
  end

  def num_instances_of(app_id)
    stats["app_id_to_count"].fetch(app_id, 0)
  end

  def zone
    stats.fetch("placement_properties", {}).fetch("zone", "default")
  end
end