# Copyright (c) 2009-2012 VMware, Inc.

require "services/api"


# FIXME: split this into seperate classe for gateway v.s. end user
# service apis.

# NOTE: this will get refactored a bit as other methods get added
# and as we start adding other legacy protocol conversions.
module VCAP::CloudController
  class LegacyService
    include VCAP::CloudController::Errors
    SERVICE_TOKEN_KEY = "HTTP_X_VCAP_SERVICE_TOKEN"
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"

    def initialize(user, logger, request, service_auth_token = nil)
      @user = user
      @logger = logger
      @request = request
      @service_auth_token = service_auth_token
    end

    def enumerate
      # FIXME: this is not correct.  It needs to encode as legacy and
      # also should be reporting services for the default app space,
      # not enumerating service types.
      logger.debug("legacy service enumerate")
      svc_api = VCAP::CloudController::Service.new(user, logger)
      api_resp = svc_api.dispatch(:enumerate)

      svcs = Yajl::Parser.parse(api_resp)
      legacy_resp = svcs["resources"].map do |svc|
        legacy_service_encoding(svc)
      end
      Yajl::Encoder.encode(legacy_resp)
    end

    def create_offering
      req = VCAP::Services::Api::ServiceOfferingRequest.decode(request.body)
      logger.debug("Create service request: #{req.extract.inspect}")

      (label, version) = req.label.split("-")
      svc_attrs = {
        :label       => label,
        :provider    => DEFAULT_PROVIDER,
        :url         => req.url,
        :description => req.description,
        :version     => version,
        :acls        => req.acls,
        :timeout     => req.timeout,
        :info_url    => req.info_url,
        :active      => req.active
      }

      provider = DEFAULT_PROVIDER
      validate_access(label, provider)

      gw_user = self.class.legacy_api_gw_user
      legacy_req = Yajl::Encoder.encode(svc_attrs)
      svc_api = VCAP::CloudController::Service.new(gw_user, logger, legacy_req)
      (_, _, svc_resp) = svc_api.dispatch(:create)
      svc = Yajl::Parser.parse(svc_resp)

      svc_plan_attrs = {
        :service_guid => svc["metadata"]["guid"],
        :name => "default",
        :description => "default plan"
      }

      legacy_req = Yajl::Encoder.encode(svc_plan_attrs)
      svc_plan_api = VCAP::CloudController::ServicePlan.new(gw_user, logger,
                                                            legacy_req)
      svc_plan_api.dispatch(:create)

      empty_json
    rescue JsonMessage::ValidationError => e
      raise InvalidRequest
    end

    def validate_access(label, provider = DEFAULT_PROVIDER)
      svc_auth_token = Models::ServiceAuthToken.find(:label => label,
                                                     :provider => provider)

      unless (svc_auth_token &&
              svc_auth_token.token_matches?(service_auth_token))
        logger.warn("unauthorized service offering")
        raise NotAuthorized
      end
    end

    def legacy_service_encoding(svc)
      {
        :name => svc["entity"]["name"],
        :type => "TODO",
        :vendor => svc["entity"]["vendor"],
        :version => svc["entity"]["version"],
        :tier => "free", # TODO
        :properties => [], # TODO
        :meta => {
          # TODO
        }
      }
    end

    private

    def empty_json
      "{}"
    end

    def self.legacy_api_gw_user
      user = Models::User.find(:guid => LEGACY_API_USER_GUID)
      if user.nil?
        user = Models::User.create(:guid => LEGACY_API_USER_GUID,
                                   :admin => true,
                                   :active => true)
      end
      user
    end

    def self.setup_routes
      klass = self

      controller.get "/services" do
        klass.new(@config, logger, request).enumerate
      end

      controller.post "/services" do
        klass.new(@config, logger, request).create
      end

      controller.before "/services/v1/*" do
        @service_auth_token = env[SERVICE_TOKEN_KEY]
      end

      controller.post "/services/v1/offerings" do
        klass.new(@config, logger, request, @service_auth_token).create_offering
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
    attr_accessor :service_auth_token
  end
end
