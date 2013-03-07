# Copyright (c) 2009-2012 VMware, Inc.

require "services/api"

module VCAP::CloudController
  class LegacyServiceGateway < LegacyApiBase
    # This endpoint does its own auth
    allow_unauthenticated_access

    include VCAP::Errors
    SERVICE_TOKEN_KEY = "HTTP_X_VCAP_SERVICE_TOKEN"
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"
    LEGACY_PLAN_OVERIDE = "100"

    def create_offering
      req = VCAP::Services::Api::ServiceOfferingRequest.decode(body)
      logger.debug("Update or create legacy service request: #{req.extract.inspect}")

      (label, version_from_label, label_dash_check) = req.label.split("-")
      if label_dash_check
        logger.warn("Unexpected dash in label: #{req.label} ")
        raise Errors::InvalidRequest.new
      end

      version = req.version_aliases["current"] || version_from_label

      provider = DEFAULT_PROVIDER
      validate_access(label, provider)

      VCAP::CloudController::SecurityContext.set(self.class.legacy_api_user)
      old_plans = Models::ServicePlan.dataset.
        join(:services, :id => :service_id).
        filter(:label => label, :provider => DEFAULT_PROVIDER).
        select_map(:name.qualify(:service_plans))

      Sequel::Model.db.transaction do
        service = Models::Service.update_or_create(
          :label => label, :provider => DEFAULT_PROVIDER
        ) do |svc|
          if svc.new?
            logger.debug2("Creating service")
          else
            logger.debug2("Updating service #{svc.guid}")
          end
          svc.set(
            :url         => req.url,
            :description => req.description,
            :version     => version,
            :acls        => req.acls,
            :timeout     => req.timeout,
            :info_url    => req.info_url,
            :active      => req.active,
          )
        end

        new_plans = Array(req.plans)
        new_plans.each do |name|
          free = (name =~ /^1[0-9][0-9]$/i ? true : false)
          Models::ServicePlan.update_or_create(
                                               :service_id => service.id,
                                               :name => name,
                                               :free => free,
          ) do |plan|
            plan.description = "dummy description"
          end
        end

        missing = old_plans - new_plans
        unless missing.empty?
          logger.info("Attempting to remove old plans: #{missing.inspect}")
          service.service_plans_dataset.filter(:name => missing).each do |plan|
            begin
              plan.destroy
            rescue Sequel::DatabaseError
              # If something is hanging on to this plan, let it live
            end
          end
        end
      end

      empty_json
    end

    def list_handles(label_and_version, provider = DEFAULT_PROVIDER)
      (label, version) = label_and_version.split("-")

      service = Models::Service[:label => label, :provider => provider]
      raise ServiceNotFound, "label=#{label} provider=#{provider}" unless service
      validate_access(label, provider)
      logger.debug("Listing handles for service: #{service.inspect}")

      handles = []
      plans_ds = service.service_plans_dataset
      instances_ds = Models::ServiceInstance.filter(:service_plan => plans_ds)
      handles += instances_ds.map do |si|
        {
          :service_id => si.gateway_name,
          :credentials => si.credentials,
          :configuration => si.gateway_data,
        }
      end

      service_bindings_ds = Models::ServiceBinding.filter(
        :service_instance => instances_ds)

      handles += service_bindings_ds.map do |sb|
        {
          :service_id => sb.gateway_name,
          :credentials => sb.credentials,
          :configuration => sb.gateway_data,
        }
      end
      Yajl::Encoder.encode({:handles => handles})
    end

    def delete(label_and_version, provider = DEFAULT_PROVIDER)
      (label, version) = label_and_version.split("-")

      validate_access(label, provider)

      VCAP::CloudController::SecurityContext.set(self.class.legacy_api_user)
      svc_guid = Models::Service[:label => label, :provider => provider].guid
      svc_api = VCAP::CloudController::Service.new(config, logger, env, params, body)
      svc_api.dispatch(:delete, svc_guid)

      empty_json
    end

    def validate_access(label, provider = DEFAULT_PROVIDER)
      raise NotAuthorized unless auth_token = env[SERVICE_TOKEN_KEY]

      svc_auth_token = Models::ServiceAuthToken[
        :label => label, :provider => provider,
      ]

      unless (svc_auth_token && svc_auth_token.token_matches?(auth_token))
        logger.warn("unauthorized service offering")
        raise NotAuthorized
      end
    end

    def get(label_and_version, provider = DEFAULT_PROVIDER)
      (label, version) = label_and_version.split("-")

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

    # NB: ambiguous API: the handle id appears in both URI and body.
    # We should only take the handle id from URI
    #
    # P.S. While I applaud Ruby for allowing this default parameter in the
    # middle, I'm really not wild for _any_ function overloading in Ruby
    def update_handle(label_and_version, provider=DEFAULT_PROVIDER, id)
      (label, version) = label_and_version.split("-")

      validate_access(label, provider)
      VCAP::CloudController::SecurityContext.set(self.class.legacy_api_user)

      req = VCAP::Services::Api::HandleUpdateRequest.decode(body)

      service = Models::Service[:label => label, :provider => provider]
      raise ServiceNotFound, "label=#{label} provider=#{provider}" unless service


      plans_ds = service.service_plans_dataset
      instances_ds = Models::ServiceInstance.filter(:service_plan => plans_ds)
      bindings_ds = Models::ServiceBinding.filter(:service_instance => instances_ds)

      if instance = instances_ds[:gateway_name => id]
        instance.set(
          :gateway_data => req.configuration,
          :credentials => req.credentials,
        )
        instance.save_changes
      elsif binding = bindings_ds[:gateway_name => id]
        binding.set(
          :configuration => req.configuration,
          :credentials => req.credentials,
        )
        binding.save_changes
      else
        # TODO: shall we add a HandleNotFound?
        raise ServiceInstanceNotFound, "label=#{label} provider=#{provider} id=#{id}"
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
      get    "/services/v1/offerings/:label_and_version/handles",               :list_handles
      get    "/services/v1/offerings/:label_and_version/:provider/handles",     :list_handles
      get    "/services/v1/offerings/:label_and_version/:provider",             :get
      get    "/services/v1/offerings/:label_and_version",                       :get
      delete "/services/v1/offerings/:label_and_version",                       :delete
      delete "/services/v1/offerings/:label_and_version/:provider",             :delete
      post   "/services/v1/offerings",                                          :create_offering
      post   "/services/v1/offerings/:label_and_version/handles/:id",           :update_handle
      post   "/services/v1/offerings/:label_and_version/:provider/handles/:id", :update_handle
    end

    def self.translate_validation_exception(e, attributes)
      Steno.logger("cc.api.legacy_svc_gw").error "#{attributes} #{e}"
      Errors::InvalidRequest.new
    end

    setup_routes
  end
end
