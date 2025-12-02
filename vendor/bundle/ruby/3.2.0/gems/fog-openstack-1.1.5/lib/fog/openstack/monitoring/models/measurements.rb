require 'fog/openstack/models/collection'
require 'fog/openstack/monitoring/models/measurement'

module Fog
  module OpenStack
    class Monitoring
      class Measurements < Fog::OpenStack::Collection
        model Fog::OpenStack::Monitoring::Measurement

        def find(options = {})
          load_response(service.find_measurements(options), 'elements')
        end
      end
    end
  end
end
