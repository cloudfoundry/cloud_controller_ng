module VCAP::CloudController
  class DropletFetcher
    def fetch(droplet_guid)
      droplet = DropletModel.where(guid: droplet_guid).first
      return nil if droplet.nil?

      [droplet, droplet.space]
    end
  end
end
