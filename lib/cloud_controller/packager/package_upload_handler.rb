require 'cloud_controller/dependency_locator'

module CloudController
  module Packager
    class PackageUploadHandler
      class PackageNotFound < StandardError
      end

      def initialize(package_guid, uploaded_files_path, cached_files_fingerprints)
        @package_guid              = package_guid
        @uploaded_files_path       = uploaded_files_path
        @cached_files_fingerprints = cached_files_fingerprints
      end

      def pack
        package = VCAP::CloudController::PackageModel.find(guid: @package_guid)
        raise PackageNotFound unless package

        begin
          checksums = packer_implementation.send_package_to_blobstore(@package_guid, @uploaded_files_path, @cached_files_fingerprints)
        rescue => e
          package.fail_upload!(e.message)
          raise e
        end

        package.succeed_upload!(checksums)

        VCAP::CloudController::BitsExpiration.new.expire_packages!(package.app)
      ensure
        FileUtils.rm_f(@uploaded_files_path) if @uploaded_files_path
      end

      def packer_implementation
        CloudController::DependencyLocator.instance.packer
      end
    end
  end
end
