require "cloud_controller/nats_messages/advertisment"

class StagerAdvertisement < Advertisement
  def stager_id
    stats["id"]
  end
end