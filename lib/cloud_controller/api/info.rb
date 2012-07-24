# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class Info < RestController::Base
    def read
      info = {
        :name        => @config[:info][:name],
        :build       => @config[:info][:build],
        :support     => @config[:info][:support_address],
        :version     => @config[:info][:version],
        :description => @config[:info][:description],
        :authorization_endpoint => @config[:uaa][:url],
        :api_version => @config[:info][:api_version]
      }

      if user
        info[:user] = user.guid
      end

      Yajl::Encoder.encode(info)
    end

    controller.get "/v2/info" do
      Info.new(@config, logger).read
    end
  end
end
