module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :file, :options, :guid_to_upgrade, :stack_name, :action

        def initialize(job_options)
          @name = job_options[:name]
          @file = job_options[:file]
          @options = job_options[:options]
          @stack_name = job_options[:stack]
          @guid_to_upgrade = job_options[:upgrade_buildpack_guid]
        end

        def max_attempts
          3
        end

        def job_name_in_configuration
          :buildpack_installer
        end

        def buildpack_uploader
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          UploadBuildpack.new(buildpack_blobstore)
        end

        private

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
