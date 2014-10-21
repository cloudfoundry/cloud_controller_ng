module VCAP::CloudController
  module Jobs
    module Runtime
      class AppBitsCopier
        attr_reader :src_app, :dest_app
        def initialize(src_app, dest_app)
          @src_app = src_app
          @dest_app = dest_app
        end
        def perform
          logger = Steno.logger("cc.background")
          logger.info("Copying the app bits from app '#{src_app.guid}' to app '#{dest_app.guid}'")

          package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
          package_blobstore.cp_file_between_keys(src_app.guid, dest_app.guid)
          dest_app.package_hash = src_app.package_hash
          dest_app.save
        end

        def job_name_in_configuration
          :app_bits_copier
        end

        def max_attempts
          1
        end
      end
    end
  end
end
