require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Jobs
    module Runtime
      class BitsServicePacker < VCAP::CloudController::Jobs::CCJob
        attr_accessor :app_guid, :uploaded_compressed_path, :fingerprints

        def initialize(app_guid, uploaded_compressed_path, fingerprints)
          @app_guid = app_guid
          @uploaded_compressed_path = uploaded_compressed_path
          @fingerprints = fingerprints
        end

        def perform
          logger.info("Packing the app bits for app '#{app_guid}' - Using BITS SERVICE")

          app = VCAP::CloudController::App.find(guid: app_guid)

          if app.nil?
            logger.error("App not found: #{app_guid}")
            return
          end

          resource_pool = CloudController::DependencyLocator.instance.bits_service_resource_pool

          if uploaded_compressed_path.to_s != ''
            entries_response = resource_pool.upload_entries(uploaded_compressed_path)
            receipt = JSON.parse(entries_response.body)
            fingerprints.concat(receipt)
          end
          package_response = resource_pool.bundles(fingerprints.to_json)

          package = Tempfile.new('package.zip').binmode
          package.write(package_response.body)
          package.close

          package_blobstore.cp_to_blobstore(package.path, app.guid)
          app.package_hash = Digester.new.digest_file(package)
          app.save
        rescue => e
          app.mark_as_failed_to_stage
          raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message) if e.is_a?(BitsService::Errors::Error)
          raise
        end

        def job_name_in_configuration
          :bits_service_packer
        end

        def max_attempts
          1
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        private

        def package_blobstore
          @package_blobstore ||= CloudController::DependencyLocator.instance.package_blobstore
        end
      end
    end
  end
end
