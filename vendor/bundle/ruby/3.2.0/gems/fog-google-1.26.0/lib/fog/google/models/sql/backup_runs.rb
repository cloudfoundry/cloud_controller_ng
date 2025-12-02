require "fog/core/collection"
require "fog/google/models/sql/backup_run"

module Fog
  module Google
    class SQL
      class BackupRuns < Fog::Collection
        model Fog::Google::SQL::BackupRun

        ##
        # Lists all backup runs associated with a given instance.
        #
        # @param [String] instance_id Instance ID
        # @return [Array<Fog::Google::SQL::BackupRun>] List of Backup run resources
        def all(instance_id)
          data = service.list_backup_runs(instance_id).to_h[:items] || []
          load(data)
        end

        ##
        # Retrieves a resource containing information about a backup run
        #
        # @param [String] instance_id Instance ID
        # @param [String] backup_run_id Backup Configuration ID
        # @return [Fog::Google::SQL::BackupRun] Backup run resource
        def get(instance_id, backup_run_id)
          backup_run = service.get_backup_run(instance_id, backup_run_id).to_h
          if backup_run
            new(backup_run)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
