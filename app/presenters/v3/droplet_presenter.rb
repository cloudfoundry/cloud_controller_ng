module VCAP::CloudController
  class DropletPresenter
    def present_json(droplet)
      droplet_hash = {
        guid:              droplet.guid,
        state:             droplet.state,
        hash:              droplet.droplet_hash,
        buildpack_guid:    droplet.buildpack_guid,
        buildpack_git_url: droplet.buildpack_git_url,
        created_at:        droplet.created_at,
        _links:            {
          self:    {
            href: "/v3/droplets/#{droplet.guid}"
          },
          package: {
            href: "/v3/packages/#{droplet.package_guid}"
          }
        },
      }

      MultiJson.dump(droplet_hash, pretty: true)
    end
  end
end
