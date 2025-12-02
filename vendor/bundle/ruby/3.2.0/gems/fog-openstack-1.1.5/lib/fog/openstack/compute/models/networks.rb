require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/network'

module Fog
  module OpenStack
    class Compute
      class Networks < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Network

        attribute :server

        def all
          requires :server

          networks = []
          server.addresses.each_with_index do |address, index|
            networks << {
              :id        => index + 1,
              :name      => address[0],
              :addresses => address[1].map { |a| a['addr'] }
            }
          end

          # TODO: convert to load_response?
          load(networks)
        end
      end
    end
  end
end
