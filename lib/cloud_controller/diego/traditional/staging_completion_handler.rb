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
              result: {
                execution_metadata: String,
                lifecycle_type:     'buildpack',
                lifecycle_metadata: {
                  buildpack_key:      String,
                  detected_buildpack: String,
                },
                process_types:      dict(Symbol, String)
              }
            }
          end
        end

        private

        def save_staging_result(app, payload)
          result = payload[:result]
          lifecycle_data = result[:lifecycle_metadata]

          app.class.db.transaction do
            app.lock!
            app.mark_as_staged
            app.update_detected_buildpack(lifecycle_data[:detected_buildpack], lifecycle_data[:buildpack_key])

            droplet = app.current_droplet
            droplet.lock!
            droplet.update_execution_metadata(result[:execution_metadata])
            if result[:process_types][:web]
              droplet.update_detected_start_command(result[:process_types][:web])
            end

            app.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
