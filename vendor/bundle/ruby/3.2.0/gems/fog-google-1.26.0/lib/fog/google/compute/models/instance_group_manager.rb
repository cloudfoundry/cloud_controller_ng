module Fog
  module Google
    class Compute
      class InstanceGroupManager < Fog::Model
        identity :name

        attribute :kind
        attribute :self_link, :aliases => "selfLink"
        attribute :description
        attribute :zone
        attribute :region
        attribute :instance_group, :aliases => "instanceGroup"
        attribute :instance_template, :aliases => "instanceTemplate"
        attribute :target_pools, :aliases => "targetPools"
        attribute :base_instance_name, :aliases => "baseInstanceName"
        attribute :current_actions, :aliases => "currentActions"
        attribute :target_size, :aliases => "targetSize"
        attribute :named_ports, :aliases => "namedPorts"

        def save
          requires :name, :zone, :base_instance_name, :target_size, :instance_template

          data = service.insert_instance_group_manager(name, zone.split("/")[-1], instance_template, base_instance_name,
          target_size, target_pools, named_ports, description)
          operation = Fog::Google::Compute::Operations.new(:service => service).get(data.name, zone.split("/")[-1])
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :name, :zone
          operation = service.delete_instance_group_manager(name, zone.split("/")[-1])
          operation.wait_for { ready? } unless async
          operation
        end

        def set_instance_template(instance_template)
          service.set_instance_template self, instance_template
        end

        def recreate_instances(instances)
          service.recreate_instances self, instances
        end

        def abandon_instances(instances)
          service.abandon_instances self, instances
        end
      end
    end
  end
end
