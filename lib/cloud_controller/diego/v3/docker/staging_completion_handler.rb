require 'securerandom'
require 'cloud_controller/diego/v3/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module V3
      module Docker
        class StagingCompletionHandler < VCAP::CloudController::Diego::V3::StagingCompletionHandler
          def initialize(droplet)
            @droplet = droplet
            @logger = Steno.logger('cc.docker.stager')
            @logger_prefix = 'diego.docker.staging.v3.'
          end

          def self.schema
            ->(_dsl) {
              {
                result: {
                  execution_metadata: String,
                  process_types: dict(Symbol, String),
                  lifecycle_type: Lifecycles::DOCKER,
                  lifecycle_metadata: {
                    docker_image: String
                  }
                }
              }
            }
          end

          private

          def save_staging_result(payload)
            droplet.class.db.transaction do
              droplet.lock!
              droplet.process_types      = payload[:result][:process_types]
              droplet.execution_metadata = payload[:result][:execution_metadata]
              droplet.mark_as_staged
              droplet.save_changes(raise_on_save_failure: true)
            end
          end
        end
      end
    end
  end
end
