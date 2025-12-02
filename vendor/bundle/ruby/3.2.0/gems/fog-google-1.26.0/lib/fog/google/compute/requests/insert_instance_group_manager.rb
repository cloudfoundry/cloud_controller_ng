module Fog
  module Google
    class Compute
      class Mock
        def insert_instance_group_manager(_name, _zone, _instance_template, _base_instance_name,
                                          _target_size, _target_pools, _named_ports, _description)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_instance_group_manager(name, zone, instance_template, base_instance_name,
                                          target_size, target_pools, named_ports, description)
          instance_group_manager = ::Google::Apis::ComputeV1::InstanceGroupManager.new(
            description: description,
            name: name,
            instance_template: instance_template.self_link,
            base_instance_name: base_instance_name,
            target_size: target_size,
            named_ports: named_ports || [],
            target_pools: target_pools || [],
          )

          @compute.insert_instance_group_manager(@project, zone, instance_group_manager)
        end
      end
    end
  end
end
