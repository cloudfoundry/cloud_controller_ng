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
          Steno.logger('cc.background').info("Packing the app bits for package '#{@package_guid}'")

          CloudController::Packager::PackageUploadHandler.new(@package_guid, @package_zip_path, @fingerprints).pack
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
      end
    end
  end
end
