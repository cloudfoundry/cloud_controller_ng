require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Compute
      class OsInterface < Fog::OpenStack::Model
        identity  :port_id
        attribute :fixed_ips, :type => :array
        attribute :mac_addr
        attribute :net_id
        attribute :port_state
      end
    end
  end
end
