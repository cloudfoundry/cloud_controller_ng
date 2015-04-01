module VCAP::CloudController
  class DropletDeleteFetcher
    def fetch(droplet_guid)
      DropletModel.where(guid: droplet_guid)
    end
  end
end
