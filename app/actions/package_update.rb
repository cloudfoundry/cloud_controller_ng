module VCAP::CloudController
  class PackageUpdate
    class InvalidPackage < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.package_update')
    end

    def update(package, message)
      validate_package_state!(package)
      validate_package_checksum!(package, message)
      @logger.info("Updating package #{package.guid}")

      package.db.transaction do
        package.lock!

        package.state           = message.state if message.requested?(:state)
        package.package_hash    = message.sha1 if message.requested?(:checksums)
        package.sha256_checksum = message.sha256 if message.requested?(:checksums)
        package.error           = message.error if message.requested?(:error)

        package.save
      end

      @logger.info("Finished updating package #{package.guid}")
      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def validate_package_checksum!(package, message)
      return if message.requested?(:checksums)

      if package.state != PackageModel::COPYING_STATE && message.state == PackageModel::READY_STATE
        raise InvalidPackage.new('Checksums required when setting state to READY')
      end
    end

    def validate_package_state!(package)
      if [PackageModel::READY_STATE, PackageModel::FAILED_STATE].include?(package.state)
        raise InvalidPackage.new('Invalid state. State is already final and cannot be modified.')
      end
    end
  end
end
