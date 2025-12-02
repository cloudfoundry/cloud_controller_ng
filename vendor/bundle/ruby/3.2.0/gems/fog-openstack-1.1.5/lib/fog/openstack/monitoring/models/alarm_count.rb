require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Monitoring
      class AlarmCount < Fog::OpenStack::Model
        attribute :links
        attribute :columns
        attribute :counts

        def to_s
          name
        end
      end
    end
  end
end
