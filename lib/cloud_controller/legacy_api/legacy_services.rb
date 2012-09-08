# Copyright (c) 2009-2012 VMware, Inc.

# NOTE: this will get refactored a bit as other methods get added
# and as we start adding other legacy protocol conversions.
module VCAP::CloudController
  class LegacyService < LegacyApiBase
    include VCAP::CloudController::Errors
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"
    LEGACY_PLAN_OVERIDE = "D100"

    def enumerate
      resp = default_space.service_instances.map do |svc_instance|
        legacy_service_encoding(svc_instance)
      end

      Yajl::Encoder.encode(resp)
    end

    def create
      legacy_attrs = Yajl::Parser.parse(body)
      raise InvalidRequest unless legacy_attrs

      logger.debug("legacy service create #{legacy_attrs}")

      svc = Models::Service.find({:label => legacy_attrs["vendor"],
                                  :version => legacy_attrs["version"]})
      unless svc
        msg = "#{legacy_attrs["vendor"]}-#{legacy_attrs["version"]}"
        raise ServiceNotFound.new(msg)
      end

      plans = svc.service_plans_dataset.filter(:name => LEGACY_PLAN_OVERIDE)
      raise ServicePlanNotFound.new(LEGACY_PLAN_OVERIDE) if plans.count == 0
      logger.warn("legacy create matched > 1 plan") unless plans.count == 1
      plan = plans.first

      attrs = {
        :name => legacy_attrs["name"],
        :space_guid => default_space.guid,
        :service_plan_guid => plan.guid
      }

      req = Yajl::Encoder.encode(attrs)
      svc_api = VCAP::CloudController::ServiceInstance.new(config, logger, env, params, req)
      svc_api.dispatch(:create)
      HTTP::OK
    end

    def delete(name)
      service_instance = service_instance_from_name(name)
      VCAP::CloudController::ServiceInstance.new(config, logger, env, params, body).dispatch(:delete, service_instance.guid)
      HTTP::OK
    end

    def enumerate_offerings
      resp = {}
      Models::Service.each do |svc|
        svc_type = LegacyService.synthesize_service_type(svc)
        resp[svc_type] ||= {}
        resp[svc_type][svc.label] ||= {}
        resp[svc_type][svc.label][svc.provider] ||= {}
        resp[svc_type][svc.label][svc.provider][svc.version] =
          legacy_service_offering_encoding(svc)
      end

      Yajl::Encoder.encode(resp)
    end

    # Keep these here in the legacy api translation rather than polluting the
    # model/schema
    def self.synthesize_service_type(svc)
      case svc.label
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

    private

    def empty_json
      "{}"
    end

    def service_instance_from_name(name)
      svc = Models::ServiceInstance.user_visible[:name => name,
                                                 :space => default_space]
      raise ServiceInstanceNotFound.new(name) unless svc
      svc
    end

    def legacy_service_encoding(svc_instance)
      plan = svc_instance.service_plan
      {
        :name => svc_instance.name,
        :type => LegacyService.synthesize_service_type(plan.service),
        :vendor => plan.service.label,
        :version => plan.service.version,
        :tier => "free",
        :properties => [],
        :meta => {}
      }
    end

    def legacy_service_offering_encoding(svc)
      svc_offering = {
        :label => "#{svc.label}-#{svc.version}",
        :provider => svc.provider,
        :url => svc.url,
        :description => svc.description,
        :info_url => svc.info_url,
        :plans => svc.service_plans.map(&:name),
        :supported_versions => [svc.version],
        :active => true
      }
    end

    def self.setup_routes
      get    "/services",       :enumerate
      post   "/services",       :create
      delete "/services/:name", :delete

      get    "/services/v1/offerings", :enumerate_offerings
    end

    setup_routes
  end
end
