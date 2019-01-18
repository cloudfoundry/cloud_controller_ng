module VCAP::CloudController
  class PackageUpdate
    class InvalidPackage < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.package_update')
    end

    def update(package, message)
      package.db.transaction do
        MetadataUpdate.update(package, message)
      end
      @logger.info("Finished updating metadata on package #{package.guid}")
      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end
  end
end
