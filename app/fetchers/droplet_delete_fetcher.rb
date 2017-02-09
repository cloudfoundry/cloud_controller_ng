module VCAP::CloudController
  class DropletDeleteFetcher
    def fetch(droplet_guid)
      droplet = DropletModel.where(guid: droplet_guid).eager(:space, space: :organization).all.first
      return nil if droplet.nil?
      org = droplet.space ? droplet.space.organization : nil

      [droplet, droplet.space, org]
    end
  end
end
