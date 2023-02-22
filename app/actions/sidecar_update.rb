module VCAP::CloudController
  class SidecarUpdate
    class InvalidSidecar < StandardError; end

    class << self
      def update(sidecar, message)
        if message.requested?(:memory_in_mb) || message.requested?(:process_types)
          validate_memory_allocation!(message, sidecar)
        end

        sidecar.name    = message.name    if message.requested?(:name)
        sidecar.command = message.command if message.requested?(:command)
        sidecar.memory  = message.memory_in_mb if message.requested?(:memory_in_mb)

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

      private

      def validate_memory_allocation!(message, sidecar)
        process_types = if message.requested?(:process_types)
                          message.process_types
                        else
                          sidecar.process_types
                        end
        memory = if message.requested?(:memory_in_mb)
                   message.memory_in_mb
                 else
                   sidecar.memory
                 end

        processes = ProcessModel.where(
          app_guid: sidecar.app_guid,
          type: process_types,
        )
        policy = SidecarMemoryLessThanProcessMemoryPolicy.new(processes, memory, sidecar)

        raise InvalidSidecar.new(policy.message) if !policy.valid?
      end
    end
  end
end
