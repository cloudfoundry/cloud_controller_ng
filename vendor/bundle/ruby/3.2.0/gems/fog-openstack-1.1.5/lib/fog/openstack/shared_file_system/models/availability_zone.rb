require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class SharedFileSystem
      class AvailabilityZone < Fog::OpenStack::Model
        identity :id

        attribute :name
        attribute :created_at
        attribute :updated_at
      end
    end
  end
end
