module Fog
  module Google
    class SQL
      ##
      # Retrieves a resource containing information about a backup run.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/backupRuns/get
      class Real
        def get_backup_run(instance_id, backup_run_id)
          @sql.get_backup_run(@project, instance_id, backup_run_id)
        end
      end

      class Mock
        def get_backup_run(_instance_id, _backup_run_id, _due_time)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
