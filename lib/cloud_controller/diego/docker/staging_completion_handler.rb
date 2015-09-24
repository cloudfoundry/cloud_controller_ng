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
              result: {
                execution_metadata: String,
                process_types:      dict(Symbol, String),
                lifecycle_type:     'docker',
                lifecycle_metadata: {
                  docker_image: String
                }
              }
            }
          end
        end

        private

        def save_staging_result(app, payload)
          result = payload[:result]

          app.class.db.transaction do
            app.lock!

            app.mark_as_staged
            app.add_new_droplet(SecureRandom.hex) # placeholder until image ID is obtained during staging

            if result.key?(:execution_metadata)
              droplet = app.current_droplet
              droplet.lock!
              droplet.update_execution_metadata(result[:execution_metadata])
              droplet.update_detected_start_command(result[:process_types][:web])
            end

            cached_image = result[:lifecycle_metadata][:docker_image]
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
