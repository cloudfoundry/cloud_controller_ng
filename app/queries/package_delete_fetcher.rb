module VCAP::CloudController
  class PackageDeleteFetcher
    def fetch(package_guid)
      PackageModel.where(guid: package_guid)
    end
  end
end
