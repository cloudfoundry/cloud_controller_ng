module VCAP::CloudController
  class PackageFetcher
    def fetch(package_guid)
      package = PackageModel.where(guid: package_guid).first
      return nil if package.nil?

      [package, package.space]
    end
  end
end
