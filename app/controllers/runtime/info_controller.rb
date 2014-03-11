module VCAP::CloudController
  class InfoController < RestController::Base
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
        api_version: VCAP::CloudController::Constants::API_VERSION
      }

      if @config[:loggregator] && @config[:loggregator][:url]
        info[:logging_endpoint] = @config[:loggregator][:url]
      end

      if user
        info[:user] = user.guid
      end

      Yajl::Encoder.encode(info)
    end
  end
end
