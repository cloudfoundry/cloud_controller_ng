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
      logger.debug("Update or create legacy service request: #{req.extract.inspect}")

      (label, version) = req.label.split("-")

      provider = DEFAULT_PROVIDER
      validate_access(label, provider)

      VCAP::CloudController::SecurityContext.current_user = self.class.legacy_api_user
      Sequel::Model.db.transaction do
        service = Models::Service.find(
          :label => label, :provider => DEFAULT_PROVIDER
        )
        if service
          logger.debug2("Updating service #{service.guid}")
          service.set(
            :url         => req.url,
            :description => req.description,
            :version     => version,
            :acls        => req.acls,
            :timeout     => req.timeout,
            :info_url    => req.info_url,
            :active      => req.active
          )
          service.save
        else
          logger.debug2("Creating service")
          service = Models::Service.create(
            :label => label,
            :provider => DEFAULT_PROVIDER,
            :url         => req.url,
            :description => req.description,
            :version     => version,
            :acls        => req.acls,
            :timeout     => req.timeout,
            :info_url    => req.info_url,
            :active      => req.active
          )
        end

        plan = Models::ServicePlan.find(
          :service_id => service.id, :name => "default"
        )
        if plan
          logger.debug2("Updating default service plan #{plan.guid}")
          plan.set(:description => "default plan")
          plan.save
        else
          logger.debug2("Creating default service plan for service #{service.label}")
          plan = Models::ServicePlan.create(
            :service_id  => service.id,
            :name        => "default",
            :description => "default plan",
          )
        end
      end

      empty_json
    rescue JsonMessage::ValidationError => e
      raise InvalidRequest
    end

    def list_handles(label, provider)
      service = Models::Service[:label => label, :provider => provider]
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

    def delete(label, provider)
      validate_access(label, provider)

      VCAP::CloudController::SecurityContext.current_user = self.class.legacy_api_user
      svc_guid = Models::Service[:label => label, :provider => provider].guid
      svc_api = VCAP::CloudController::Service.new(config, logger)
      svc_api.dispatch(:delete, svc_guid)

      empty_json
    rescue JsonMessage::ValidationError => e
      raise InvalidRequest
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

    def get(label, provider)
      validate_access(label, provider)

      service = Models::Service[:label => label, :provider => provider]
      offering = {
        :label => label,
        :provider => provider,
        :url => service.url,
      }

      [
        :description,
        :info_url,
        # :tags,
        # :plans,
        # :cf_plan_id,
        # :plan_options,
        # :binding_options,
        :acls,
        :active,
        :timeout,
        :provider,
        # :supported_versions,
        # :version_aliases,
      ].each do |field|
          if service.values[:field]
            offering[:field] = service[:field]
          end
        end
        offering[:plans] = service.service_plans.map(&:name)
        Yajl::Encoder.encode(offering)
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

      controller.delete "/services/v1/offerings/:label/:provider" do
        LegacyServiceGateway.new(@config, logger, request, @service_auth_token).delete(params[:label], params[:provider])
      end

      controller.delete "/services/v1/offerings/:label" do
        LegacyServiceGateway.new(@config, logger, request, @service_auth_token).delete(params[:label], DEFAULT_PROVIDER)
      end

      controller.post "/services/v1/offerings" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).create_offering
      end

      controller.get "/services/v1/offerings/:label/:provider" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).get(params[:label], params[:provider])
      end

      controller.get "/services/v1/offerings/:label" do
        LegacyServiceGateway.new(@config, logger, request.body, @service_auth_token).get(params[:label], DEFAULT_PROVIDER)
      end
    end

    setup_routes
    attr_accessor :service_auth_token
  end
end
