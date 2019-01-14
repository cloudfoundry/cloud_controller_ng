require 'cloud_controller/upload_buildpack'

module VCAP::CloudController
  module Jobs
    module V3
      class BuildpackBits
        attr_reader :buildpack_guid
        alias_method :resource_guid, :buildpack_guid

        def initialize(buildpack_guid, buildpack_bits_path, buildpack_bits_name)
          @buildpack_guid = buildpack_guid
          @file_path = buildpack_bits_path
          @file_name = buildpack_bits_name
        end

        def perform
          Steno.logger('cc.background').info("Uploading buildpack bits for the buildpack '#{buildpack_guid}'")

          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack = Buildpack.find(guid: buildpack_guid)

          VCAP::CloudController::UploadBuildpack.new(buildpack_blobstore).upload_buildpack(buildpack, file_path, file_name)
        ensure
          FileUtils.rm_f(file_path)
        end

        def job_name_in_configuration
          :buildpack_bits
        end

        def max_attempts
          1
        end

        def display_name
          'buildpack.upload'
        end

        def resource_type
          'buildpack'
        end

        private

        attr_reader :file_path, :file_name
      end
    end
  end
end
