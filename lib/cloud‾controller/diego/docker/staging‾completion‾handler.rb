require 'securerandom'
require 'cloud_controller/diego/staging_completion_handler'
require 'actions/droplet_create'

module VCAP::CloudController
  module Diego
    module Docker
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandler
        def logger_prefix
          'diego.staging.docker.'
        end

        def self.schema
          ->(_dsl) {
            {
              result: {
                execution_metadata: String,
                process_types:      dict(Symbol, String),
                lifecycle_type:     Lifecycles::DOCKER,
                lifecycle_metadata: {
                  docker_image: String,
                }
              }
            }
          }
        end

        private

        def handle_missing_droplet!(payload)
          @droplet = create_droplet_from_build(build)
        end

        def create_droplet_from_build(build)
          VCAP::CloudController::DropletCreate.new.create_docker_droplet(build)
        end

        def save_staging_result(payload)
          docker_image = payload.dig(:result, :lifecycle_metadata, :docker_image)

          droplet.class.db.transaction do
            droplet.lock!
            build.lock!
            droplet.process_types        = payload[:result][:process_types]
            droplet.execution_metadata   = payload[:result][:execution_metadata]
            droplet.docker_receipt_image = docker_image unless docker_image.blank?
            droplet.mark_as_staged
            build.mark_as_staged
            build.save_changes(raise_on_save_failure: true)
            droplet.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
