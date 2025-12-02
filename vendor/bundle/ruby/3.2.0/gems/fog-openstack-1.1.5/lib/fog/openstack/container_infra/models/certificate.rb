require_relative 'base'

module Fog
  module OpenStack
    class  ContainerInfra
      class Certificate < Fog::OpenStack::ContainerInfra::Base
        identity :bay_uuid

        attribute :pem
        attribute :csr

        def create
          requires :csr, :bay_uuid
          merge_attributes(service.create_certificate(attributes).body)
          self
        end
      end
    end
  end
end
