# Copyright (c) 2009-2012 VMware, Inc.


module VCAP::CloudController
  class LegacyInfo
    include VCAP::CloudController::Errors

    def initialize(config, logger, user, request)
      @config = config
      @logger = logger
      @user = user
      @request = request
    end

    def info
      info = {
        :name        => config[:info][:name],
        :build       => config[:info][:build],
        :support     => config[:info][:support_address],
        :version     => config[:info][:version],
        :description => config[:info][:description],
        :authorization_endpoint => config[:uaa][:url],
        # TODO: enable once json schema is updated
        # :allow_debug => # config[:allow_debug]
        :allow_debug => false
      }

      # If there is a logged in user, give out additional information
      if user
        info[:user]       = user.guid
        info[:limits]     = { :memory => 1024,
                              :services => 20,
                              :apps => 20 } # TODO: user.account_capacity
        info[:usage]      = { :memory => 0,
                              :services => 0,
                              :apps => 0 } # user.account_usage
        info[:frameworks] = {} # StagingPlugin.manifests_info
      end

      Yajl::Encoder.encode(info)
    end

    def service_info
      svc_api = VCAP::CloudController::Service.new(user, logger, @request)
      api_resp = svc_api.dispatch(:enumerate)

      svcs = Yajl::Parser.parse(api_resp)
      # TODO
      # legacy_resp = svcs["resources"].map do |svc|
      #   legacy_svc_encoding(svc)
      # end
      legacy_resp = []

      Yajl::Encoder.encode(legacy_resp)
    end

    def legacy_svc_encoding(svc)
      {
        # TODO
      }
    end

    private

    def self.setup_routes
      klass = self
      controller.get "/info" do
        klass.new(@config, logger, @user, request).info
      end

      controller.get "/info/services" do
        klass.new(@config, logger, @user, request).service_info
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
    attr_accessor :config, :logger, :user
  end
end
