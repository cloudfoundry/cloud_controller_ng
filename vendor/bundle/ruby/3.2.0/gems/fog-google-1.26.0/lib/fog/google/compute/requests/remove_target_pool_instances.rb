module Fog
  module Google
    class Compute
      class Mock
        def remove_target_pool_instances(_target_pool, _region, _instances)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def remove_target_pool_instances(target_pool, region, instances)
          instance_lst = instances.map do |link|
            ::Google::Apis::ComputeV1::InstanceReference.new(
              instance: link
            )
          end

          @compute.remove_target_pool_instance(
            @project, region.split("/")[-1], target_pool,
            ::Google::Apis::ComputeV1::RemoveTargetPoolsInstanceRequest.new(
              instances: instance_lst
            )
          )
        end
      end
    end
  end
end
