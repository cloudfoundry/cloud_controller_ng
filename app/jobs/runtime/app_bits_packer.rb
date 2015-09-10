require 'cloud_controller/blobstore/cdn'
require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Jobs
    module Runtime
      class AppBitsPacker < VCAP::CloudController::Jobs::CCJob
        attr_accessor :app_guid, :uploaded_compressed_path, :fingerprints

        def initialize(app_guid, uploaded_compressed_path, fingerprints)
          @app_guid = app_guid
          @uploaded_compressed_path = uploaded_compressed_path
          @fingerprints = fingerprints
        end

        def perform
          logger.info("Packing the app bits for app '#{app_guid}'")

          app = VCAP::CloudController::App.find(guid: app_guid)

          if app.nil?
            logger.error("App not found: #{app_guid}")
            return
          end

          package_blobstore     = CloudController::DependencyLocator.instance.package_blobstore
          global_app_bits_cache = CloudController::DependencyLocator.instance.global_app_bits_cache
          max_package_size      = VCAP::CloudController::Config.config[:packages][:max_package_size] || 512 * 1024 * 1024

          app_bits_packer = AppBitsPackage.new(
            package_blobstore,
            global_app_bits_cache,
            max_package_size,
            VCAP::CloudController::Config.config[:directories][:tmpdir])

          app_bits_packer.create(
            app,
            uploaded_compressed_path,
            CloudController::Blobstore::FingerprintsCollection.new(fingerprints))
        end

        def job_name_in_configuration
          :app_bits_packer
        end

        def max_attempts
          1
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
