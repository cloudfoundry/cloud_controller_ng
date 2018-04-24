require 'cloud_controller/diego/staging_completion_handler'
require 'utils/uri_utils'

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
                  optional(:buildpack_key) =>      String,
                  detected_buildpack: String,
                  optional(:buildpacks) => [
                    {
                      key: String,
                      optional(:name) => String,
                      optional(:version) => String,
                    }
                  ]
                },
                process_types:      dict(Symbol, String)
              }
            }
          }
        end

        private

        def handle_missing_droplet!(payload)
          build.fail_to_stage!(nil, 'no droplet')
        end

        def save_staging_result(payload)
          lifecycle_data = payload[:result][:lifecycle_metadata]
          buildpack_key  = nil
          buildpack_url  = nil

          if UriUtils.is_buildpack_uri?(lifecycle_data[:buildpack_key])
            buildpack_url = lifecycle_data[:buildpack_key]
          else
            buildpack_key = lifecycle_data[:buildpack_key]
          end

          droplet.class.db.transaction do
            droplet.lock!
            build.lock!
            droplet.set_buildpack_receipt(
              buildpack_key:       buildpack_key,
              buildpack_url:       buildpack_url,
              detect_output:       lifecycle_data[:detected_buildpack],
              requested_buildpack: droplet.buildpack_lifecycle_data.buildpacks.first
            )
            # TODO: What if lifecycle_data[:buildpacks] is nil?  Delete current buildpacks?
            if lifecycle_data[:buildpacks]
              droplet.buildpack_lifecycle_data.buildpacks = lifecycle_data[:buildpacks]
              droplet.buildpack_lifecycle_data.save_changes(raise_on_save_failure: true)
            end
            droplet.save_changes(raise_on_save_failure: true)
            build.droplet.reload
            droplet.mark_as_staged
            build.mark_as_staged
            droplet.process_types      = payload[:result][:process_types]
            droplet.execution_metadata = payload[:result][:execution_metadata]
            build.save_changes(raise_on_save_failure: true)
            droplet.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
