module VCAP::CloudController
  class PackageStageFetcher
    def fetch(package_guid, buildpack_guid)
      package = PackageModel.where(guid: package_guid).eager(:app, :space, space: :organization).all.first
      return nil if package.nil?

      buildpack = Buildpack.find(guid: buildpack_guid)
      org       = package.space ? package.space.organization : nil

      [package, package.app, package.space, org, buildpack]
    end
  end
end
