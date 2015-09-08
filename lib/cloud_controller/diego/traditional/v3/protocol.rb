require 'cloud_controller/diego/traditional/v3/buildpack_entry_generator'
require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/traditional/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        class Protocol
          def initialize(blobstore_url_generator, egress_rules)
            @blobstore_url_generator   = blobstore_url_generator
            @buildpack_entry_generator = V3::BuildpackEntryGenerator.new(@blobstore_url_generator)
            @egress_rules              = egress_rules
          end

          def stage_package_message(package, staging_config, staging_details)
            lifecycle_data                                    = LifecycleData.new
            lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.v3_app_buildpack_cache_download_url(package.app_guid, staging_details.stack)
            lifecycle_data.build_artifacts_cache_upload_uri   = @blobstore_url_generator.v3_app_buildpack_cache_upload_url(package.app_guid, staging_details.stack)
            lifecycle_data.app_bits_download_uri              = @blobstore_url_generator.package_download_url(package)
            lifecycle_data.droplet_upload_uri                 = @blobstore_url_generator.package_droplet_upload_url(staging_details.droplet.guid)
            lifecycle_data.buildpacks                         = @buildpack_entry_generator.buildpack_entries(staging_details.buildpack_info)
            lifecycle_data.stack                              = staging_details.stack

            staging_request                  = StagingRequest.new
            staging_request.app_id           = staging_details.droplet.guid
            staging_request.log_guid         = package.app_guid
            staging_request.environment      = VCAP::CloudController::Diego::Environment.hash_to_diego_env(staging_details.environment_variables)
            staging_request.memory_mb        = staging_details.memory_limit
            staging_request.disk_mb          = staging_details.disk_limit
            staging_request.file_descriptors = staging_config[:minimum_staging_file_descriptor_limit]
            staging_request.egress_rules     = @egress_rules.staging
            staging_request.timeout          = staging_config[:timeout_in_seconds]
            staging_request.lifecycle        = 'buildpack'
            staging_request.lifecycle_data   = lifecycle_data.message

            staging_request.message
          end

          def stage_package_request(package, staging_config, staging_details)
            stage_package_message(package, staging_config, staging_details).to_json
          end
        end
      end
    end
  end
end
