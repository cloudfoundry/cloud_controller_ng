module VCAP::CloudController
  class SidecarCreate
    class InvalidSidecar < StandardError
    end

    class << self
      def create(app_guid, message, origin=SidecarModel::ORIGIN_USER)
        logger = Steno.logger('cc.action.sidecar_create')

        validate_memory_allocation!(app_guid, message) if message.requested?(:memory_in_mb)

        sidecar = SidecarModel.new(
          app_guid: app_guid,
          name:     message.name,
          command:  message.command,
          memory:  message.memory_in_mb,
          origin: origin,
        )

        SidecarModel.db.transaction do
          sidecar.save
          message.process_types.each do |process_type|
            SidecarProcessTypeModel.create(type: process_type, sidecar_guid: sidecar.guid, app_guid: sidecar.app_guid)
          end
        end

        logger.info("Finished creating sidecar #{sidecar.guid}")
        sidecar
      rescue Sequel::ValidationFailed => e
        error = InvalidSidecar.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
      end

      private

      def validate_memory_allocation!(app_guid, message)
        processes = ProcessModel.where(
          app_guid: app_guid,
          type: message.process_types,
        )
        policy = SidecarMemoryLessThanProcessMemoryPolicy.new(processes, message.memory_in_mb)

        raise InvalidSidecar.new(policy.message) if !policy.valid?
      end
    end
  end
end
