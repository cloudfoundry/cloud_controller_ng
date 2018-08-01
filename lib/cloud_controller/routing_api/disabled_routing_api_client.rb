module VCAP::CloudController::RoutingApi
  class RoutingApiDisabled < StandardError; end

  class DisabledClient
    def enabled?
      false
    end

    def router_groups
      raise RoutingApiDisabled
    end

    def router_group(guid)
      raise RoutingApiDisabled
    end

    def router_group_guid(name)
      raise RoutingApiDisabled
    end
  end
end
