require 'httpclient'
require 'uri'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/opi/helpers'
require 'cloud_controller/opi/env_hash'
require 'cloud_controller/opi/base_client'

module OPI
  class StagerClient < BaseClient
    def stage(staging_guid, staging_details)
      logger.info('stage.request', staging_guid: staging_guid)

      if staging_details.lifecycle.type == VCAP::CloudController::Lifecycles::DOCKER
        complete_staging(staging_guid, staging_details)
      elsif staging_details.lifecycle.type == VCAP::CloudController::Lifecycles::BUILDPACK
        staging_request = to_request(staging_guid, staging_details)
        start_staging(staging_guid, staging_request)
      else
        raise("lifecycle type `#{staging_details.lifecycle.type}` is invalid")
      end
    end

    def stop_staging(staging_guid); end

    private

    def start_staging(staging_guid, staging_request)
      payload = MultiJson.dump(staging_request)
      response = client.post("/stage/#{staging_guid}", body: payload)
      if response.status_code != 202
        response_json = OPI.recursive_ostruct(JSON.parse(response.body))
        logger.info('stage.response', staging_guid: staging_guid, error: response_json.message)
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', response_json.message)
      end
    end

    def complete_staging(staging_guid, staging_details)
      build = VCAP::CloudController::BuildModel.find(guid: staging_guid)
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Build not found') if build.nil?

      completion_handler = VCAP::CloudController::Diego::Docker::StagingCompletionHandler.new(build)
      payload = {
        result: {
          lifecycle_type: 'docker',
          lifecycle_metadata: {
            docker_image: staging_details.package.image
          },
          process_types: { web: '' },
          execution_metadata: '{\"cmd\":[],\"ports\":[{\"Port\":8080,\"Protocol\":\"tcp\"}]}'
        }
      }
      completion_handler.staging_complete(payload, staging_details.start_after_staging)
    end

    def to_request(staging_guid, staging_details)
      lifecycle_type = staging_details.lifecycle.type
      action_builder = VCAP::CloudController::Diego::LifecycleProtocol.protocol_for_type(lifecycle_type).staging_action_builder(config, staging_details)
      lifecycle_data = action_builder.lifecycle_data

      cc_uploader_url = config.get(:opi, :cc_uploader_url)
      droplet_upload_uri = "#{cc_uploader_url}/v1/droplet/#{staging_guid}?cc-droplet-upload-uri=#{lifecycle_data[:droplet_upload_uri]}"

      {
          app_guid: staging_details.package.app_guid,
          environment: build_env(staging_details.environment_variables) + action_builder.task_environment_variables,
          completion_callback: staging_completion_callback(staging_details),
          lifecycle_data: {
              droplet_upload_uri: droplet_upload_uri,
              app_bits_download_uri: lifecycle_data[:app_bits_download_uri],
              buildpacks: lifecycle_data[:buildpacks]
          }
      }
    end

    def staging_completion_callback(staging_details)
      port   = config.get(:tls_port)
      scheme = 'https'

      auth      = "#{config.get(:internal_api, :auth_user)}:#{CGI.escape(config.get(:internal_api, :auth_password))}"
      host_port = "#{config.get(:internal_service_hostname)}:#{port}"
      path      = "/internal/v3/staging/#{staging_details.staging_guid}/build_completed?start=#{staging_details.start_after_staging}"
      "#{scheme}://#{auth}@#{host_port}#{path}"
    end

    def build_env(environment)
      env = OPI::EnvHash.muse(environment)
      env.map { |i| ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value']) }
    end

    def logger
      @logger ||= Steno.logger('cc.bbs.stager_client')
    end
  end
end
