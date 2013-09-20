module VCAP::CloudController
  class InfoController < RestController::Base
    allow_unauthenticated_access

    def read
      info = {
        :name        => @config[:info][:name],
        :build       => @config[:info][:build],
        :support     => @config[:info][:support_address],
        :version     => @config[:info][:version],
        :description => @config[:info][:description],
        :authorization_endpoint => @config[:login] ? @config[:login][:url] : @config[:uaa][:url],
        :api_version => @config[:info][:api_version]
      }

      if user
        info[:user] = user.guid
      end

      Yajl::Encoder.encode(info)
    end

    get "/v2/info", :read
  end
end
