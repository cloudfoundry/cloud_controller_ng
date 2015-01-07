module VCAP::CloudController
  class PackagePresenter
    def present_json(package)
      package_hash = {
        guid: package.guid,
        type: package.type,
        hash: package.package_hash,
        state: package.state,
        error: package.error,
        created_at: package.created_at,
        _links: {
          self: {
            href: "/v3/packages/#{package.guid}"
          },
          app: {
            href: "/v3/apps/#{package.app_guid}",
          },
        },
      }

      MultiJson.dump(package_hash, pretty: true)
    end
  end
end
