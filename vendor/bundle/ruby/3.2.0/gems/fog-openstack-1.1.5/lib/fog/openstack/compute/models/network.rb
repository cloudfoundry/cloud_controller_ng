require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Compute
      class Network < Fog::OpenStack::Model
        identity  :id
        attribute :name
        attribute :addresses
      end
    end
  end
end
