require 'fog/openstack/models/collection'
require 'fog/openstack/monitoring/models/alarm_count'

module Fog
  module OpenStack
    class Monitoring
      class AlarmCounts < Fog::OpenStack::Collection
        model Fog::OpenStack::Monitoring::AlarmCount

        def get(options = {})
          load_response(service.get_alarm_counts(options))
        end
      end
    end
  end
end
