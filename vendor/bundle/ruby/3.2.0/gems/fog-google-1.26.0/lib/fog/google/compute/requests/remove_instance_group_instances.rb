module Fog
  module Google
    class Compute
      class Mock
        def add_instance_group_instances(_group, _zone, _instances)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def remove_instance_group_instances(group_name, zone, instances)
          instances.map! do |instance|
            if instance.start_with?("https:")
              ::Google::Apis::ComputeV1::InstanceReference.new(instance: instance)
            else
              ::Google::Apis::ComputeV1::InstanceReference.new(
                instance: "https://www.googleapis.com/compute/#{api_version}/projects/#{@project}/zones/#{zone}/instances/#{instance}\n"
              )
            end
          end

          request = ::Google::Apis::ComputeV1::InstanceGroupsRemoveInstancesRequest.new(
            instances: instances
          )
          @compute.remove_instance_group_instances(
            @project,
            zone,
            group_name,
            request
          )
        end
      end
    end
  end
end
