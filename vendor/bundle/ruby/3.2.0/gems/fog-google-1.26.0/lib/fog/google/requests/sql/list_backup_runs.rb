module Fog
  module Google
    class SQL
      ##
      # Lists all backup runs associated with a given instance and configuration in the
      # reverse chronological order of the enqueued time
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/backupRuns/list

      class Real
        def list_backup_runs(instance_id, max_results: nil, page_token: nil)
          @sql.list_backup_runs(@project, instance_id,
                                :max_results => max_results,
                                :page_token => page_token)
        end
      end

      class Mock
        def list_backup_runs(_instance_id, _backup_configuration_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
