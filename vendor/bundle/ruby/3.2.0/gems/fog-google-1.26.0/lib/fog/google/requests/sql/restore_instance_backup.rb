module Fog
  module Google
    class SQL
      ##
      # Restores a backup of a Cloud SQL instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/restoreBackup

      class Real
        def restore_instance_backup(instance_id, backup_run_id)
          request = ::Google::Apis::SqladminV1beta4::RestoreInstancesBackupRequest.new(
            restore_backup_context: ::Google::Apis::SqladminV1beta4::RestoreBackupContext.new(
              backup_run_id: backup_run_id,
              instance_id: instance_id,
              kind: "sql#restoreBackupContext"
            )
          )
          @sql.restore_instance_backup(@project, instance_id, request)
        end
      end

      class Mock
        def restore_instance_backup(_instance_id, _backup_run_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
