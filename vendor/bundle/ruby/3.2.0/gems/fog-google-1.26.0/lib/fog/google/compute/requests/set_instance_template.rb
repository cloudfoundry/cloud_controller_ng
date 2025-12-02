module Fog
  module Google
    class Compute
      class Mock
        def set_instance_template(_instance_group_manager, _instance_template)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def set_instance_template(instance_group_manager, instance_template)
          request = ::Google::Apis::ComputeV1::InstanceGroupManagersSetInstanceTemplateRequest.new(
            :instance_template => instance_template.class == String ? instance_template : instance_template.self_link
          )
          if instance_group_manager.zone
            zone = instance_group_manager.zone.split("/")[-1]
            @compute.set_instance_group_manager_instance_template(@project, zone, instance_group_manager.name, request)
          else
            region = instance_group_manager.region.split("/")[-1]
            @compute.set_region_instance_group_manager_instance_template(@project, region, instance_group_manager.name, request)
          end
        end
      end
    end
  end
end
