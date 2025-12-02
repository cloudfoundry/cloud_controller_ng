require 'fog/openstack/models/collection'
require 'fog/openstack/container_infra/models/cluster'

module Fog
  module OpenStack
    class  ContainerInfra
      class Clusters < Fog::OpenStack::Collection

        model Fog::OpenStack::ContainerInfra::Cluster

        def all
          load_response(service.list_clusters, "clusters")
        end

        def get(cluster_uuid_or_name)
          resource = service.get_cluster(cluster_uuid_or_name).body
          new(resource)
        rescue Fog::OpenStack::ContainerInfra::NotFound
          nil
        end
      end
    end
  end
end
