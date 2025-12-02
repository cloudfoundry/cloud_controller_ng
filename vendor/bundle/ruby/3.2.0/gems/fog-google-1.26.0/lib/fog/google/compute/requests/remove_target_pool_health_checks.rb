module Fog
  module Google
    class Compute
      class Mock
        def remove_target_pool_health_checks(_target_pool, _region, _health_checks)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def remove_target_pool_health_checks(target_pool, region, health_checks)
          health_check_lst = health_checks.map do |hc|
            ::Google::Apis::ComputeV1::HealthCheckReference.new(health_check: hc)
          end

          @compute.remove_target_pool_health_check(
            @project,
            region.split("/")[-1],
            target_pool,
            ::Google::Apis::ComputeV1::RemoveTargetPoolsHealthCheckRequest.new(
              health_checks: health_check_lst
            )
          )
        end
      end
    end
  end
end
