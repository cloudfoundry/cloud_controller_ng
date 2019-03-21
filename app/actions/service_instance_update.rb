module VCAP::CloudController
  class ServiceInstanceUpdate
    class InvalidServiceInstance < StandardError
    end

    class << self
      def update(service_instance, message)
        logger = Steno.logger('cc.action.service_instance_update')

        service_instance.db.transaction do
          MetadataUpdate.update(service_instance, message)
        end
        logger.info("Finished updating metadata on service_instance #{service_instance.guid}")
        service_instance
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceInstance.new(e.message)
      end
    end
  end
end
