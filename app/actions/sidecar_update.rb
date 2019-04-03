module VCAP::CloudController
  class SidecarUpdate
    class InvalidSidecar < StandardError; end

    class << self
      def update(sidecar, message)
        sidecar.name    = message.name    if message.requested?(:name)
        sidecar.command = message.command if message.requested?(:command)

        SidecarModel.db.transaction do
          sidecar.save

          if message.requested?(:process_types)
            sidecar.sidecar_process_types_dataset.destroy
            message.process_types.each do |process_type|
              sidecar_process_type = SidecarProcessTypeModel.new(type: process_type, app_guid: sidecar.app_guid)
              sidecar.add_sidecar_process_type(sidecar_process_type)
            end
          end
        end

        sidecar
      rescue Sequel::ValidationFailed => e
        error = InvalidSidecar.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
      end
    end
  end
end
