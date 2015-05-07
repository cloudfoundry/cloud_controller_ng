require 'cloud_controller/diego/traditional/buildpack_entry_generator'
require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/traditional/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Traditional
      class Protocol
        def initialize(blobstore_url_generator, common_protocol)
          @blobstore_url_generator = blobstore_url_generator
          @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
          @common_protocol = common_protocol
        end

        def stage_app_request(app, staging_config)
          stage_app_message(app, staging_config).to_json
        end

        def desire_app_request(app, default_health_check_timeout)
          desire_app_message(app, default_health_check_timeout).to_json
        end

        def stage_app_message(app, staging_config)
          lifecycle_data = LifecycleData.new
          lifecycle_data.app_bits_download_uri = @blobstore_url_generator.app_package_download_url(app)
          lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.buildpack_cache_download_url(app)
          lifecycle_data.build_artifacts_cache_upload_uri = @blobstore_url_generator.buildpack_cache_upload_url(app)
          lifecycle_data.droplet_upload_uri = @blobstore_url_generator.droplet_upload_url(app)
          lifecycle_data.buildpacks = @buildpack_entry_generator.buildpack_entries(app)
          lifecycle_data.stack = app.stack.name

          staging_request = StagingRequest.new
          staging_request.app_id = app.guid
          staging_request.log_guid = app.guid
          staging_request.environment = Environment.new(app).as_json
          staging_request.memory_mb = [app.memory, staging_config[:minimum_staging_memory_mb]].max
          staging_request.disk_mb = [app.disk_quota, staging_config[:minimum_staging_disk_mb]].max
          staging_request.file_descriptors = [app.file_descriptors, staging_config[:minimum_staging_file_descriptor_limit]].max
          staging_request.egress_rules = @common_protocol.staging_egress_rules
          staging_request.timeout = staging_config[:timeout_in_seconds]
          staging_request.lifecycle = 'buildpack'
          staging_request.lifecycle_data = lifecycle_data.message

          staging_request.message
        end

        def desire_app_message(app, default_health_check_timeout)
          message = {
            'process_guid' => ProcessGuid.from_app(app),
            'memory_mb' => app.memory,
            'disk_mb' => app.disk_quota,
            'file_descriptors' => app.file_descriptors,
            'droplet_uri' => @blobstore_url_generator.perma_droplet_download_url(app.guid),
            'stack' => app.stack.name,
            'start_command' => app.command,
            'execution_metadata' => app.execution_metadata,
            'environment' => Environment.new(app).as_json,
            'num_instances' => app.desired_instances,
            'routes' => app.uris,
            'log_guid' => app.guid,
            'health_check_type' => app.health_check_type,
            'health_check_timeout_in_seconds' => app.health_check_timeout || default_health_check_timeout,
            'egress_rules' => @common_protocol.running_egress_rules(app),
            'etag' => app.updated_at.to_f.to_s,
            'allow_ssh' => app.enable_ssh,
          }

          message
        end
      end
    end
  end
end
