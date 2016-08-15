module VCAP::CloudController
  module Jobs
    module V3
      class PackageBits
        def initialize(package_guid, package_zip_path, fingerprints)
          @package_guid     = package_guid
          @package_zip_path = package_zip_path
          @fingerprints     = fingerprints
        end

        def perform
          Steno.logger('cc.background').info("Packing the app bits for package '#{@package_guid}'")

          if use_bits_service
            Jobs::Runtime::BitsServicePacker.new(@package_guid, @package_zip_path, @fingerprints).perform
          else
            AppBitsPackage.new.create_package_in_blobstore(
              @package_guid,
              @package_zip_path,
              CloudController::Blobstore::FingerprintsCollection.new(@fingerprints)
            )
          end
        end

        def use_bits_service
          Config.config.dig(:bits_service, :enabled)
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
