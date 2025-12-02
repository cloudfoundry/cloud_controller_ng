module Fog
  module Google
    class Compute
      class Mock
        def abandon_instances(_instance_group_manager, _instances)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def abandon_instances(instance_group_manager, instances)
          request = ::Google::Apis::ComputeV1::InstanceGroupManagersAbandonInstancesRequest.new(
            instances: instances.map{ |i| i.class == String ? i : i.self_link }
          )
          if instance_group_manager.zone
            zone = instance_group_manager.zone.split("/")[-1]
            @compute.abandon_instance_group_manager_instances(@project, zone, instance_group_manager.name, request)
          else
            region = instance_group_manager.region.split("/")[-1]
            @compute.abandon_region_instance_group_manager_instances(@project, region, instance_group_manager.name, request)
          end
        end
      end
    end
  end
end
