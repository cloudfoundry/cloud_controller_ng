require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/os_interface'

module Fog
  module OpenStack
    class Compute
      class OsInterfaces < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::OsInterface

        attribute :server

        def all
          requires :server

          data = service.list_os_interfaces(server.id)
          load_response(data, 'interfaceAttachments')
        end

        def get(port_id)
          requires :server

          data = service.get_os_interface(server.id,port_id)
          load_response(data, 'interfaceAttachment')
        end
      end
    end
  end
end
