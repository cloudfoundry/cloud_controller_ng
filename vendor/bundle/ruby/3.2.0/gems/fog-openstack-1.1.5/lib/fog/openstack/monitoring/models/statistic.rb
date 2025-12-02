require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Monitoring
      class Statistic < Fog::OpenStack::Model
        identity :id

        attribute :name
        attribute :dimension
        attribute :columns
        attribute :statistics

        def to_s
          name
        end
      end
    end
  end
end
