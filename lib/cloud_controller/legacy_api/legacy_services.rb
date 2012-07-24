# Copyright (c) 2009-2012 VMware, Inc.

require "services/api"

# NOTE: this will get refactored a bit as other methods get added
# and as we start adding other legacy protocol conversions.
module VCAP::CloudController
  class LegacyService < LegacyApiBase
    include VCAP::CloudController::Errors
    DEFAULT_PROVIDER = "core"
    LEGACY_API_USER_GUID = "legacy-api"
    LEGACY_PLAN_OVERIDE = "D100"

    def enumerate
      resp = default_space.service_instances_dataset.
        # I want LINQ-style auto join on FK for this:
        # filter { service.provider == "core" }.
        join(:services, :id => :service_id).filter(:provider => DEFAULT_PROVIDER).
        select_all(:service_instances).
        map do |svc_instance|
        legacy_service_encoding(svc_instance)
      end

      Yajl::Encoder.encode(resp)
    end

    def create
      legacy_attrs = Yajl::Parser.parse(request.body)
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

      # FIXME: these should be set at the next level and come from the svc gw
      if legacy_attrs["credentials"]
        attrs[:credentials] = legacy_attrs["credentials"]
      end

      req = Yajl::Encoder.encode(attrs)
      svc_api = VCAP::CloudController::ServiceInstance.new(logger, req)
      svc_api.dispatch(:create)
      HTTP::OK
    end

    def delete(name)
      service_instance = service_instance_from_name(name)
      VCAP::CloudController::ServiceInstance.new(logger).dispatch(:delete, service_instance.guid)
      HTTP::OK
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

    def self.setup_routes
      controller.get "/services" do
        LegacyService.new(@config, logger, request).enumerate
      end

      controller.post "/services" do
        LegacyService.new(@config, logger, request).create
      end

      controller.delete "/services/:name" do |name|
        LegacyService.new(@config, logger, request).delete(name)
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
    attr_accessor :request, :logger
  end
end
