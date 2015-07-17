require 'cloud_controller/blobstore/cdn'
require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Jobs
    module V3
      class PackageBits
        def initialize(package_guid, uploaded_compressed_path)
          @package_guid = package_guid
          @uploaded_compressed_path = uploaded_compressed_path
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Packing the app bits for package '#{@package_guid}'")

          package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
          max_package_size = VCAP::CloudController::Config.config[:packages][:max_package_size] || 512 * 1024 * 1024

          app_bits_packer = AppBitsPackage.new(package_blobstore, nil, max_package_size, VCAP::CloudController::Config.config[:directories][:tmpdir])
          app_bits_packer.create_package_in_blobstore(@package_guid, @uploaded_compressed_path)
        end

        def job_name_in_configuration
          :package_bits
        end

        def max_attempts
          1
        end
      end
    end
  end
end
