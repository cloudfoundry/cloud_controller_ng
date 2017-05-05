require 'securerandom'
require 'cloud_controller/diego/staging_completion_handler'

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
                  optional(:docker_user) => String,
                  optional(:docker_password) => String,
                }
              }
            }
          }
        end

        private

        def save_staging_result(payload)
          docker_image = payload.dig(:result, :lifecycle_metadata, :docker_image)
          docker_username = payload.dig(:result, :lifecycle_metadata, :docker_user)
          docker_password = payload.dig(:result, :lifecycle_metadata, :docker_password)

          droplet.class.db.transaction do
            droplet.lock!
            droplet.process_types        = payload[:result][:process_types]
            droplet.execution_metadata   = payload[:result][:execution_metadata]
            droplet.docker_receipt_image = docker_image unless docker_image.blank?
            droplet.docker_receipt_username = docker_username unless docker_username.blank?
            droplet.docker_receipt_password = docker_password unless docker_password.blank?
            droplet.mark_as_staged
            droplet.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
