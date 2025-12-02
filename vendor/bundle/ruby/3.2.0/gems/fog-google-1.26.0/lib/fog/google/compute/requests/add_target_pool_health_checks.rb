module Fog
  module Google
    class Compute
      class Mock
        def add_target_pool_health_checks(_target_pool, _region, _health_checks)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def add_target_pool_health_checks(target_pool, region, health_checks)
          check_list = health_checks.map do |health_check|
            ::Google::Apis::ComputeV1::HealthCheckReference.new(
              health_check: health_check
            )
          end

          @compute.add_target_pool_health_check(
            @project,
            region.split("/")[-1],
            target_pool,
            ::Google::Apis::ComputeV1::AddTargetPoolsHealthCheckRequest.new(
              health_checks: check_list
            )
          )
        end
      end
    end
  end
end
