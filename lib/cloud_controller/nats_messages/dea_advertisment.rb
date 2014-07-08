require "cloud_controller/nats_messages/advertisment"

class DeaAdvertisement < Advertisement
  def dea_id
    stats["id"]
  end

  def increment_instance_count(app_id)
    stats["app_id_to_count"][app_id] = num_instances_of(app_id) + 1
  end
end
