module Fog
  module Google
    class SQL
      ##
      # Creates a new backup run on demand. This method is applicable only to Second
      # Generation instances.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/backupRuns/insert
      class Real
        def insert_backup_run(instance_id, backup_run = {})
          @sql.insert_backup_run(
            @project,
            instance_id,
            ::Google::Apis::SqladminV1beta4::BackupRun.new(**backup_run)
          )
        end
      end

      class Mock
        def insert_backup_run(_instance_id, _run)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
