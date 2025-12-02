require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/lb_health_monitor'

module Fog
  module OpenStack
    class Network
      class LbHealthMonitors < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::LbHealthMonitor

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_lb_health_monitors(filters), 'health_monitors')
        end

        def get(health_monitor_id)
          if health_monitor = service.get_lb_health_monitor(health_monitor_id).body['health_monitor']
            new(health_monitor)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
