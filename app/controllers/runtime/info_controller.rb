module VCAP::CloudController
  class InfoController < RestController::BaseController
    allow_unauthenticated_access

    get '/v2/info', :read
    def read
      info = {
        name: @config[:info][:name],
        build: @config[:info][:build],
        support: @config[:info][:support_address],
        version: @config[:info][:version],
        description: @config[:info][:description],
        authorization_endpoint: @config[:login] ? @config[:login][:url] : @config[:uaa][:url],
        token_endpoint: config[:uaa][:url],
        min_cli_version: @config[:info][:min_cli_version],
        min_recommended_cli_version: @config[:info][:min_recommended_cli_version],
        api_version: VCAP::CloudController::Constants::API_VERSION,
        app_ssh_endpoint: @config[:info][:app_ssh_endpoint],
        app_ssh_host_key_fingerprint: @config[:info][:app_ssh_host_key_fingerprint],
        app_ssh_oauth_client: @config[:info][:app_ssh_oauth_client],
      }

      if @config[:routing_api] && @config[:routing_api][:url]
        info[:routing_endpoint] = @config[:routing_api][:url]
      end

      if @config[:loggregator] && @config[:loggregator][:url]
        info[:logging_endpoint] = @config[:loggregator][:url]
      end

      if @config[:doppler][:enabled]
        info[:doppler_logging_endpoint] = @config[:doppler][:url]
      end

      if @config[:info][:custom]
        info[:custom] = @config[:info][:custom]
      end

      if user
        info[:user] = user.guid
      end

      MultiJson.dump(info)
    end
  end
end
