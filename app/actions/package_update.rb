module VCAP::CloudController
  class PackageUpdate
    class InvalidPackage < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.package_update')
    end

    def update(package, message)
      package.db.transaction do
        if package.type == PackageModel::DOCKER_TYPE && (message.username || message.password)
          package.docker_username = message.username unless message.username.nil?
          package.docker_password = message.password unless message.password.nil?
          package.save
        end
        MetadataUpdate.update(package, message)
      end
      @logger.info("Finished updating package #{package.guid}")
      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end
  end
end
