# Copyright (c) 2009-2012 VMware, Inc.

require "services/api"

module VCAP::CloudController
  class LegacyServiceGateway < LegacyApiBase
    include VCAP::CloudController::Errors
    SERVICE_TOKEN_KEY = "HTTP_X_VCAP_SERVICE_TOKEN"
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"
    LEGACY_PLAN_OVERIDE = "D100"

    def initialize(config, logger, body, service_auth_token)
      @service_auth_token = service_auth_token
      super(config, logger, body)
    end

    def create_offering
      req = VCAP::Services::Api::ServiceOfferingRequest.decode(body)
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
      svc_api = VCAP::CloudController::Service.new(config, logger, legacy_req)
      (_, _, svc_resp) = svc_api.dispatch(:create)
      svc = Yajl::Parser.parse(svc_resp)

      svc_plan_attrs = {
        :service_guid => svc["metadata"]["guid"],
        :name => "default",
        :description => "default plan"
      }

      legacy_req = Yajl::Encoder.encode(svc_plan_attrs)
      svc_plan_api = VCAP::CloudController::ServicePlan.new(config, logger, legacy_req)
      svc_plan_api.dispatch(:create)

      empty_json
    rescue JsonMessage::ValidationError => e
      raise InvalidRequest
    end

    def list_handles(label, provider)
      service = Models::Service[
        :label => label, :provider => provider,
      ]
      raise ServiceNotFound, "label=#{label} provider=#{provider}" unless service
      logger.debug("Listing handles for service: #{service.inspect}")
      handles = []
      handles += service.service_instances.map do |si|
        {
          :service_id => si.gateway_name,
          :credentials => si.credentials,
          :configuration => si.gateway_data,
        }
      end
      handles += service.service_bindings.map do |sb|
        {
          :service_id => sb.gateway_name,
          :credentials => sb.credentials,
          :configuration => sb.configuration,
        }
      end
      Yajl::Encoder.encode({:handles => handles})
    end

    def validate_access(label, provider = DEFAULT_PROVIDER)
      svc_auth_token = Models::ServiceAuthToken[
        :label => label, :provider => provider,
      ]

      unless (svc_auth_token &&
              svc_auth_token.token_matches?(service_auth_token))
        logger.warn("unauthorized service offering")
        raise NotAuthorized
      end
    end

    private

    def empty_json
      "{}"
    end

    def self.legacy_api_user
      user = Models::User.find(:guid => LEGACY_API_USER_GUID)
      if user.nil?
        user = Models::User.create(
          :guid => LEGACY_API_USER_GUID,
          :admin => true,
          :active => true,
        )
      end
      user
    end

    def self.setup_routes
      controller.before "/services/v1/*" do
        @service_auth_token = env[SERVICE_TOKEN_KEY]
      end

      controller.get "/services/v1/offerings/:label/handles" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).list_handles(params[:label], DEFAULT_PROVIDER)
      end

      controller.get "/services/v1/offerings/:label/:provider/handles" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).list_handles(params[:label], params[:provider])
      end

      controller.post "/services/v1/offerings" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).create_offering
      end
    end

    setup_routes
    attr_accessor :service_auth_token
  end
end
