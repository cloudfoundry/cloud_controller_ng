require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module Traditional
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
        def initialize(runners)
          super(runners, Steno.logger('cc.stager'), 'diego.staging.')
        end

        def self.success_parser
          @staging_response_schema ||= Membrane::SchemaParser.parse do
            {
              execution_metadata:     String,
              lifecycle_data:         {
                buildpack_key:      String,
                detected_buildpack: String,
              }
            }
          end
        end

        private

        def save_staging_result(app, payload)
          lifecycle_data = payload[:lifecycle_data]
          metadata = MultiJson.load(payload[:execution_metadata], symbolize_keys: true)

          app.class.db.transaction do
            app.lock!
            app.mark_as_staged
            app.update_detected_buildpack(lifecycle_data[:detected_buildpack], lifecycle_data[:buildpack_key])

            droplet = app.current_droplet
            droplet.lock!
            droplet.update_execution_metadata(payload[:execution_metadata])
            if metadata[:process_types] && metadata[:process_types][:web]
              droplet.update_detected_start_command(metadata[:process_types][:web])
            end

            app.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
