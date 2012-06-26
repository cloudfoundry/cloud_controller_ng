# Copyright (c) 2009-2012 VMware, Inc.

require "services/api"


# FIXME: split this into seperate classe for gateway v.s. end user
# service apis.

# NOTE: this will get refactored a bit as other methods get added
# and as we start adding other legacy protocol conversions.
module VCAP::CloudController
  class LegacyService < LegacyApiBase
    include VCAP::CloudController::Errors
    SERVICE_TOKEN_KEY = "HTTP_X_VCAP_SERVICE_TOKEN"
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"
    LEGACY_PLAN_OVERIDE = "free"

    def initialize(config, logger, request, service_auth_token = nil)
      super(config, logger, request)
      @service_auth_token = service_auth_token
    end

    def enumerate
      # FIXME: this is not correct.  It needs to encode as legacy and
      # also should be reporting services for the default app space,
      # not enumerating service types.
      logger.debug("legacy service enumerate")

      api = VCAP::CloudController::AppSpace.new(logger)
      api_resp = api.dispatch(:enumerate_related, default_app_space.guid, :service_instances)

      svcs = Yajl::Parser.parse(api_resp)
      legacy_resp = svcs["resources"].map do |svc|
        legacy_service_encoding(svc)
      end
      Yajl::Encoder.encode(legacy_resp)
    end

    # {"type":"database","tier":"free","vendor":"mysql","version":"5.1","name":"mysql-b7d4e"}
    def create
      legacy_attrs = Yajl::Parser.parse(request.body)
      raise InvalidRequest unless legacy_attrs

      logger.debug("legacy service create #{legacy_attrs}")

      svc = Models::Service.find({:label => legacy_attrs["vendor"],
                                  :version => legacy_attrs["version"]})
      raise InvalidRequest unless svc

      svc_plans = svc.service_plans_dataset.filter(:name => LEGACY_PLAN_OVERIDE)
      raise InvalidRequest if svc_plans.count == 0
      logger.warn("legacy create matched > 1 plan") unless svc_plans.count == 1
      svc_plan = svc_plans.first

      attrs = {
        :name => legacy_attrs["name"],
        :app_space_guid => default_app_space.guid,
        :service_plan_guid => svc_plan.guid,
        # FIXME: these should be set at the next level and come from the svc gw
        :credentials => {}
      }

      legacy_req = Yajl::Encoder.encode(attrs)
      svc_api = VCAP::CloudController::ServiceInstance.new(logger, legacy_req)
      svc_api.dispatch(:create)
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

      VCAP::CloudController::SecurityContext.current_user = self.class.legacy_api_user
      legacy_req = Yajl::Encoder.encode(svc_attrs)
      svc_api = VCAP::CloudController::Service.new(logger, legacy_req)
      (_, _, svc_resp) = svc_api.dispatch(:create)
      svc = Yajl::Parser.parse(svc_resp)

      svc_plan_attrs = {
        :service_guid => svc["metadata"]["guid"],
        :name => "default",
        :description => "default plan"
      }

      legacy_req = Yajl::Encoder.encode(svc_plan_attrs)
      svc_plan_api = VCAP::CloudController::ServicePlan.new(logger, legacy_req)
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
      plan = Models::ServicePlan[:guid => svc["entity"]["service_plan_guid"]]
      {
        :name => svc["entity"]["name"],
        :type => "TODO",
        :vendor => plan.service.label,
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

      controller.post "/services" do
        klass.new(@user, logger, request).create
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
