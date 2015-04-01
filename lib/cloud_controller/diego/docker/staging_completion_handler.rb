require 'securerandom'
require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module Docker
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
        def initialize(runners)
          super(runners, Steno.logger('cc.docker.stager'), 'diego.docker.staging.')
        end

        def self.success_parser
          @staging_response_schema ||= Membrane::SchemaParser.parse do
            {
              execution_metadata: String,
              detected_start_command: Hash,
              optional(:lifecycle_data) => Hash
            }
          end
        end

        private

        def save_staging_result(app, payload)
          app.class.db.transaction do
            app.lock!

            app.mark_as_staged
            app.add_new_droplet(SecureRandom.hex) # placeholder until image ID is obtained during staging

            if payload.key?(:execution_metadata)
              droplet = app.current_droplet
              droplet.lock!
              droplet.update_execution_metadata(payload[:execution_metadata])
              if payload.key?(:detected_start_command)
                droplet.update_detected_start_command(payload[:detected_start_command][:web])
              end
            end

            cached_image = payload[:lifecycle_data] && payload[:lifecycle_data][:docker_image]
            if cached_image.present?
              droplet.update_cached_docker_image(cached_image)
            else
              droplet.update_cached_docker_image(nil)
            end

            app.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
