require 'cloud_controller/diego/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandler
        def logger_prefix
          'diego.staging.buildpack.'
        end

        def self.schema
          ->(_dsl) {
            {
              result: {
                execution_metadata: String,
                lifecycle_type:     Lifecycles::BUILDPACK,
                lifecycle_metadata: {
                  buildpack_key:      String,
                  detected_buildpack: String,
                },
                process_types:      dict(Symbol, String)
              }
            }
          }
        end

        private

        def save_staging_result(payload)
          lifecycle_data = payload[:result][:lifecycle_metadata]
          buildpack_key  = nil
          buildpack_url  = nil

          if lifecycle_data[:buildpack_key].is_uri?
            buildpack_url = lifecycle_data[:buildpack_key]
          else
            buildpack_key = lifecycle_data[:buildpack_key]
          end

          droplet.class.db.transaction do
            droplet.lock!
            droplet.set_buildpack_receipt(
              buildpack_key:       buildpack_key,
              buildpack_url:       buildpack_url,
              detect_output:       lifecycle_data[:detected_buildpack],
              requested_buildpack: droplet.buildpack_lifecycle_data.buildpack
            )
            droplet.mark_as_staged
            droplet.process_types      = payload[:result][:process_types]
            droplet.execution_metadata = payload[:result][:execution_metadata]
            droplet.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
