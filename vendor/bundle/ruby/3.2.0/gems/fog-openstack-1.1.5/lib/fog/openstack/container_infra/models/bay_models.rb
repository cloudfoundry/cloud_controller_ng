require 'fog/openstack/models/collection'
require 'fog/openstack/container_infra/models/bay_model'

module Fog
  module OpenStack
    class  ContainerInfra
      class BayModels < Fog::OpenStack::Collection
        model Fog::OpenStack::ContainerInfra::BayModel

        def all
          load_response(service.list_bay_models, 'baymodels')
        end

        def get(bay_model_uuid_or_name)
          resource = service.get_bay_model(bay_model_uuid_or_name).body
          new(resource)
        rescue Fog::OpenStack::ContainerInfra::NotFound
          nil
        end
      end
    end
  end
end
