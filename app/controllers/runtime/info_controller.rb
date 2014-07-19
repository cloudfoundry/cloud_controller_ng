module VCAP::CloudController
  class InfoController < RestController::BaseController
    allow_unauthenticated_access

    get "/v2/info", :read
    def read
      info = {
        name: @config[:info][:name],
        build: @config[:info][:build],
        support: @config[:info][:support_address],
        version: @config[:info][:version],
        description: @config[:info][:description],
        authorization_endpoint: @config[:login] ? @config[:login][:url] : @config[:uaa][:url],
        token_endpoint: config[:uaa][:url],
        api_version: VCAP::CloudController::Constants::API_VERSION
      }

      if @config[:loggregator] && @config[:loggregator][:url]
        info[:logging_endpoint] = @config[:loggregator][:url]
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
