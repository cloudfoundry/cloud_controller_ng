require 'cloud_controller/diego/v3/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module V3
      module Buildpack
        class StagingCompletionHandler < VCAP::CloudController::Diego::V3::StagingCompletionHandler
          def self.schema
            ->(_dsl) {
              {
                result: {
                  execution_metadata: String,
                  lifecycle_type: Lifecycles::BUILDPACK,
                  lifecycle_metadata: {
                    buildpack_key: String,
                    detected_buildpack: String,
                  },
                  process_types: dict(Symbol, String)
                }
              }
            }
          end

          private

          def save_staging_result(payload)
            lifecycle_data = payload[:result][:lifecycle_metadata]
            buildpack_key = lifecycle_data[:buildpack_key]
            buildpack = droplet.buildpack_lifecycle_data.buildpack if buildpack_key.blank?

            droplet.class.db.transaction do
              droplet.lock!
              droplet.process_types               = payload[:result][:process_types]
              droplet.execution_metadata          = payload[:result][:execution_metadata]
              droplet.buildpack_receipt_buildpack = buildpack if buildpack
              droplet.update_buildpack_receipt(buildpack_key) if buildpack_key
              droplet.mark_as_staged
              droplet.save_changes(raise_on_save_failure: true)
            end
          end
        end
      end
    end
  end
end
