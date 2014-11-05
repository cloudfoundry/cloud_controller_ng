module VCAP::CloudController
  module Jobs
    module Runtime
      class PendingPackagesCleanup < Struct.new(:expiration_in_seconds)

        def perform
          cutoff_time = Time.now - expiration_in_seconds
          App.where("package_pending_since < ?", cutoff_time).update(
            package_state: "FAILED",
            staging_failed_reason: "StagingTimeExpired",
            package_pending_since: nil,
          )
        end

        def job_name_in_configuration
          :pending_packages
        end

        def max_attempts
          1
        end
      end
    end
  end
end
