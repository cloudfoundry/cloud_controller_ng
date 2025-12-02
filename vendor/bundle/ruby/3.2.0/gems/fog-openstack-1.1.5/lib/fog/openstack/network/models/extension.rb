require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Network
      class Extension < Fog::OpenStack::Model
        identity :id
        attribute :name
        attribute :links
        attribute :description
        attribute :alias
      end
    end
  end
end
