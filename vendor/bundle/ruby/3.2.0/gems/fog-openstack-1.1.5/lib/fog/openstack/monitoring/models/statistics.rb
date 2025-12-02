require 'fog/openstack/models/collection'
require 'fog/openstack/monitoring/models/statistic'

module Fog
  module OpenStack
    class Monitoring
      class Statistics < Fog::OpenStack::Collection
        model Fog::OpenStack::Monitoring::Statistic

        def all(options = {})
          load_response(service.list_statistics(options), 'elements')
        end
      end
    end
  end
end
