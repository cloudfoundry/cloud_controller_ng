# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyInfo < LegacyApiBase
    include VCAP::CloudController::Errors

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

    # Legacy format
    #
    # {
    #   "key-value": {
    #     "redis": {
    #       "2.2": {
    #         "id": 2,
    #         "vendor": "redis",
    #         "version": "2.2",
    #         "tiers": {
    #           "free": {
    #             "options": {

    #             },
    #             "order": 1
    #           },
    #           "sptest": {
    #             "options": {

    #             },
    #             "order": 2
    #           }
    #         },
    #         "type": "key-value",
    #         "description": "Redis key-value store service"
    #       }
    #     },
    #     "mongodb": {
    #       "1.8": {
    #         "id": 3,
    #         "vendor": "mongodb",
    #         "version": "1.8",
    #         "tiers": {
    #           "free": {
    #             "options": {

    #             },
    #             "order": 1
    #           },
    #           "sptest": {
    #             "options": {

    #             },
    #             "order": 2
    #           }
    #         },
    #         "type": "key-value",
    #         "description": "MongoDB NoSQL store"
    #       }
    #     }
    #   },<snip>
    # }
    def service_info
      svc_api = VCAP::CloudController::Service.new(logger)
      api_resp = svc_api.dispatch(:enumerate)

      svcs = Yajl::Parser.parse(api_resp)

      legacy_resp = {}
      svcs["resources"].each do |svc|
        svc_type = synthesize_service_type(svc)
        label = svc["entity"]["label"]
        version = svc["entity"]["version"]
        legacy_resp[svc_type] ||= {}
        legacy_resp[svc_type][label] ||= {}
        legacy_resp[svc_type][label][version] ||= {}
        legacy_resp[svc_type][label][version] = legacy_svc_encoding(svc, user)
      end

      Yajl::Encoder.encode(legacy_resp)
    end

    # Keep these here in the legacy api translation rather than polluting the
    # model/schema
    def synthesize_service_type(svc)
      case svc["entity"]["label"]
      when /mysql/
        "database"
      when /postgresql/
        "database"
      when /redis/
        "key-value"
      when /mongodb/
        "key-value"
      else
        "generic"
      end
    end

    def legacy_svc_encoding(svc, user)
      {
        :id      => svc["entity"]["guid"],
        :vendor  => svc["entity"]["label"],
        :version => svc["entity"]["version"],
        :type    => synthesize_service_type(svc),
        :description => svc["entity"]["description"] || '-',

        # The legacy vmc/sts clients only handles free.  Don't
        # try to pretent otherwise.
        :tiers => {
          "free" => {
            "options" => { },
            "order" => 1
          }
        }
      }
    end

    private

    def self.setup_routes
      klass = self
      controller.get "/info" do
        klass.new(@config, logger, request).info
      end

      controller.get "/info/services" do
        klass.new(@config, logger, request).service_info
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
    attr_accessor :config, :logger, :user
  end
end
