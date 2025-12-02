module Fog
  module Google
    class Compute
      class Mock
        def add_instance_group_instances(_group_name, _zone, _instances)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def add_instance_group_instances(group_name, zone, instances)
          instances.map! do |instance|
            if instance.start_with?("https:")
              ::Google::Apis::ComputeV1::InstanceReference.new(instance: instance)
            else
              ::Google::Apis::ComputeV1::InstanceReference.new(
                instance: "https://www.googleapis.com/compute/#{api_version}/projects/#{@project}/zones/#{zone}/instances/#{instance}\n"
              )
            end
          end

          request = ::Google::Apis::ComputeV1::InstanceGroupsAddInstancesRequest.new(
            instances: instances
          )
          @compute.add_instance_group_instances(
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
