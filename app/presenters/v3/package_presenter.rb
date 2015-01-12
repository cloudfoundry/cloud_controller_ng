module VCAP::CloudController
  class PackagePresenter
    def present_json(package)
      package_hash = {
        guid: package.guid,
        type: package.type,
        hash: package.package_hash,
        url: package.url,
        state: package.state,
        error: package.error,
        created_at: package.created_at,
        _links: {
          self: {
            href: "/v3/packages/#{package.guid}"
          },
          upload: {
            href: "/v3/packages/#{package.guid}/upload",
          },
          space: {
            href: "/v2/spaces/#{package.space_guid}",
          },
        },
      }

      MultiJson.dump(package_hash, pretty: true)
    end
  end
end
