module VCAP::CloudController
  class PackageDeleteFetcher
    def fetch(package_guid)
      package = PackageModel.where(guid: package_guid).eager(:app, :space, space: :organization).all.first
      return nil if package.nil?

      org = package.space ? package.space.organization : nil

      [package, package.space, org]
    end
  end
end
