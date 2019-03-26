module VCAP::CloudController
  class SidecarCreate
    class InvalidSidecar < StandardError
    end

    class << self
      def create(app_guid, message)
        logger = Steno.logger('cc.action.sidecar_create')
        sidecar = SidecarModel.new(
          app_guid: app_guid,
          name:     message.name,
          command:  message.command,
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
    end
  end
end
