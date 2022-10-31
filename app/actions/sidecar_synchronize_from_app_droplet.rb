module VCAP::CloudController
  class SidecarSynchronizeFromAppDroplet
    class Error < StandardError
    end
    class ConflictingSidecarsError < Error
    end

    class << self
      def synchronize(app)
        app.db.transaction do
          SidecarDelete.delete(app.sidecars_dataset.where(origin: SidecarModel::ORIGIN_BUILDPACK))

          app.droplet.sidecars&.each do |sidecar_params|
            translate_memory_for_message(sidecar_params)
            sidecar_create_message = SidecarCreateMessage.new(sidecar_params)
            raise_error_if_sidecar_names_conflict(app, sidecar_create_message)
            sidecar = SidecarCreate.create(app.guid, sidecar_create_message, SidecarModel::ORIGIN_BUILDPACK)
            TelemetryLogger.v3_emit(
              'create-sidecar',
              {
                'app-id' => sidecar.app_guid,
              },
              {
                'api-version' => 'v3',
                'origin' => 'buildpack',
                'memory-in-mb' => sidecar.memory,
                'process-types' => sidecar.process_types,
              }
            )
          end
        end
      end

      def raise_error_if_sidecar_names_conflict(app, sidecar_create_message)
        if app.sidecars_dataset.where(name: sidecar_create_message.name, origin: SidecarModel::ORIGIN_USER).present?
          raise ConflictingSidecarsError.new(
            "Buildpack defined sidecar \'#{sidecar_create_message.name}\'"\
            ' conflicts with an existing user-defined sidecar.'\
            " Consider renaming \'#{sidecar_create_message.name}\'."
          )
        end
      end

      private

      def translate_memory_for_message(sidecar_params)
        sidecar_params['memory_in_mb'] = sidecar_params['memory']
      end
    end
  end
end
