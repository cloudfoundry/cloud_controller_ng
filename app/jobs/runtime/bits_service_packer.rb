require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Jobs
    module Runtime
      class BitsServicePacker < VCAP::CloudController::Jobs::CCJob
        def initialize(app_guid, zip_of_files_not_in_blobstore_path, cached_fingerprints)
          @app_guid = app_guid
          @zip_of_files_not_in_blobstore_path = zip_of_files_not_in_blobstore_path
          @cached_fingerprints = cached_fingerprints
        end

        def perform
          logger.info("Packing the app bits for app '#{@app_guid}' - Using BITS SERVICE")

          app = VCAP::CloudController::App.find(guid: @app_guid)
          if app.nil?
            logger.error("App not found: #{@app_guid}")
            return
          end

          fingerprints_from_upload = upload_missing_entries(@zip_of_files_not_in_blobstore_path)
          app.package_hash = generate_package(@cached_fingerprints | fingerprints_from_upload, 'package.zip', app.guid)
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

        private

        def upload_missing_entries(zip_of_files_not_in_blobstore_path)
          if zip_of_files_not_in_blobstore_path.to_s != ''
            entries_response = resource_pool.upload_entries(zip_of_files_not_in_blobstore_path)
            JSON.parse(entries_response.body)
          else
            []
          end
        end

        def generate_package(fingerprints, package_filename, app_guid)
          bundle_response = resource_pool.bundles(fingerprints.to_json)
          package = create_temp_file_with_content(package_filename, bundle_response.body)
          package_blobstore.cp_to_blobstore(package.path, app_guid)
          Digester.new.digest_file(package)
        end

        def create_temp_file_with_content(filename, content)
          package = Tempfile.new(filename).binmode
          package.write(content)
          package.close
          package
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def resource_pool
          CloudController::DependencyLocator.instance.bits_service_resource_pool
        end

        def package_blobstore
          CloudController::DependencyLocator.instance.package_blobstore
        end
      end
    end
  end
end
