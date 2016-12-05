require 'cloud_controller/diego/buildpack/lifecycle_data'
require 'cloud_controller/diego/buildpack/buildpack_entry_generator'
require 'cloud_controller/diego/buildpack/staging_action_builder'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        class LifecycleProtocol
          class InvalidDownloadUri < StandardError; end

          def initialize(blobstore_url_generator=::CloudController::DependencyLocator.instance.blobstore_url_generator)
            @blobstore_url_generator = blobstore_url_generator
            @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
          end

          def lifecycle_data(staging_details)
            lifecycle_data                                    = Diego::Buildpack::LifecycleData.new
            lifecycle_data.app_bits_download_uri              = @blobstore_url_generator.package_download_url(staging_details.package)
            lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.buildpack_cache_download_url(
              staging_details.package.app_guid,
              staging_details.lifecycle.staging_stack
            )
            lifecycle_data.build_artifacts_cache_upload_uri = @blobstore_url_generator.buildpack_cache_upload_url(
              staging_details.package.app_guid,
              staging_details.lifecycle.staging_stack
            )
            lifecycle_data.droplet_upload_uri                 = @blobstore_url_generator.droplet_upload_url(staging_details.droplet.guid)
            lifecycle_data.buildpacks                         = @buildpack_entry_generator.buildpack_entries(staging_details.lifecycle.buildpack_info)
            lifecycle_data.stack                              = staging_details.lifecycle.staging_stack

            lifecycle_data.message
          rescue Membrane::SchemaValidationError => e
            if e.message =~ /app_bits_download_uri/
              logger.error "app_bits_download_uri is nil for package #{staging_details.package.guid}"
              raise InvalidDownloadUri.new("Failed to get blobstore download url for package #{staging_details.package.guid}")
            else
              raise e
            end
          end

          def staging_action_builder(config, staging_details)
            StagingActionBuilder.new(config, staging_details, lifecycle_data(staging_details))
          end

          def task_action_builder(config, task)
            TaskActionBuilder.new(config, task, task_lifecycle_data(task))
          end

          def desired_lrp_builder(config, app_request)
            DesiredLrpBuilder.new(config, app_request)
          end

          def desired_app_message(process)
            {
              'start_command' => process.command.nil? ? process.detected_start_command : process.command,
              'droplet_uri' => @blobstore_url_generator.unauthorized_perma_droplet_download_url(process),
              'droplet_hash' => process.current_droplet.droplet_hash,
            }
          end

          private

          def task_lifecycle_data(task)
            {
              droplet_uri: droplet_download_uri(task),
              stack: task.app.lifecycle_data.stack
            }
          end

          def droplet_download_uri(task)
            download_url = @blobstore_url_generator.droplet_download_url(task.droplet)
            raise InvalidDownloadUri.new("Failed to get blobstore download url for droplet #{task.droplet.guid}") unless download_url
            download_url
          end

          def logger
            @logger ||= Steno.logger('cc.diego.tr')
          end
        end
      end
    end
  end
end
