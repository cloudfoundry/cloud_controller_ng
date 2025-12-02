module Fog
  module Google
    class SQL
      ##
      # Restarts a Cloud SQL instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/restart

      class Real
        def restart_instance(instance_id)
          @sql.restart_instance(@project, instance_id)
        end
      end

      class Mock
        def restart_instance(_instance_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
