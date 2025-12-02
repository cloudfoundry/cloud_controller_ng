module Fog
  module Google
    class Compute
      class Mock
        def set_target_pool_backup(_target_pool, _region, _backup_target,
                                   _failover_ratio: nil)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def set_target_pool_backup(target_pool, region, backup_target,
                                   failover_ratio: nil)
          target_ref = ::Google::Apis::ComputeV1::TargetReference.new(
            target: backup_target
          )

          @compute.set_target_pool_backup(
            project,
            region.split("/")[-1],
            target_pool,
            target_ref,
            failover_ratio: failover_ratio
          )
        end
      end
    end
  end
end
