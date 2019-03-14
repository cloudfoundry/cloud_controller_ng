module VCAP::CloudController
  class PackageFetcher
    def fetch(package_guid)
      package = PackageModel.where(guid: package_guid).eager(:space, space: :organization).first
      return nil if package.nil?

      org = package.space ? package.space.organization : nil
      [package, package.space, org]
    end
  end
end
