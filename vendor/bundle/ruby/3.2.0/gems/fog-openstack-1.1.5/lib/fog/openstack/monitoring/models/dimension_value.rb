require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Monitoring
      class DimensionValue < Fog::OpenStack::Model
        identity :id

        attribute :metric_name
        attribute :dimension_name
        attribute :values

        def to_s
          name
        end
      end
    end
  end
end
