module VCAP::CloudController
  class InfoController < RestController::BaseController
    allow_unauthenticated_access

    get '/v2/info', :read
    def read
      info = {
        name: @config.get(:info, :name),
        build: @config.get(:info, :build),
        support: @config.get(:info, :support_address),
        version: @config.get(:info, :version),
        description: @config.get(:info, :description),
        authorization_endpoint: @config.get(:login, :url),
        token_endpoint: config.get(:uaa, :url),
        min_cli_version: @config.get(:info, :min_cli_version),
        min_recommended_cli_version: @config.get(:info, :min_recommended_cli_version),
        app_ssh_endpoint: @config.get(:info, :app_ssh_endpoint),
        app_ssh_host_key_fingerprint: @config.get(:info, :app_ssh_host_key_fingerprint),
        app_ssh_oauth_client: @config.get(:info, :app_ssh_oauth_client),
        doppler_logging_endpoint: @config.get(:doppler, :url),
        api_version: VCAP::CloudController::Constants::API_VERSION,
        osbapi_version: VCAP::CloudController::Constants::OSBAPI_VERSION
      }

      info[:routing_endpoint] = @config.get(:routing_api, :url) if @config.get(:routing_api) && @config.get(:routing_api, :url)

      info[:custom] = @config.get(:info, :custom) if @config.get(:info, :custom)

      info[:user] = user.guid if user

      MultiJson.dump(info)
    end
  end
end
