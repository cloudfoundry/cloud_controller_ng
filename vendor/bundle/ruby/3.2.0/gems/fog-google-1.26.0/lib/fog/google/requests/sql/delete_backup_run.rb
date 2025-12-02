module Fog
  module Google
    class SQL
      ##
      # Deletes the backup taken by a backup run.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/backupRuns/delete
      class Real
        def delete_backup_run(instance_id, backup_run_id)
          @sql.delete_backup_run(@project, instance_id, backup_run_id)
        end
      end

      class Mock
        def delete_backup_run(_instance_id, _run)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
