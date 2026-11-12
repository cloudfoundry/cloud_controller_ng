require 'cloud_controller/packager/package_upload_handler'

module VCAP::CloudController
  module Jobs
    module V3
      class PackageBits
        attr_reader :package_guid
        alias_method :resource_guid, :package_guid

        def initialize(package_guid, package_zip_path, fingerprints)
          @package_guid     = package_guid
          @package_zip_path = package_zip_path
          @fingerprints     = fingerprints
        end

        def perform
          start_time = Time.now
          logger.info('package_upload.job.start', {
                        package_guid: @package_guid,
                        package_zip_path_present: @package_zip_path.present?,
                        fingerprint_count: @fingerprints.size
                      })

          CloudController::Packager::PackageUploadHandler.new(@package_guid, @package_zip_path, @fingerprints).pack

          logger.info('package_upload.job.done', {
                        package_guid: @package_guid,
                        duration_ms: elapsed_ms(start_time)
                      })
        rescue StandardError => e
          logger.info('package_upload.job.failed', {
                        package_guid: @package_guid,
                        duration_ms: elapsed_ms(start_time),
                        error_class: e.class.name,
                        error: e.message
                      })
          raise
        end

        def job_name_in_configuration
          :package_bits
        end

        def max_attempts
          1
        end

        def display_name
          'package.upload'
        end

        def resource_type
          'package'
        end

        private

        def logger
          Steno.logger('cc.background')
        end

        def elapsed_ms(start_time)
          ((Time.now - start_time) * 1000).round
        end
      end
    end
  end
end
