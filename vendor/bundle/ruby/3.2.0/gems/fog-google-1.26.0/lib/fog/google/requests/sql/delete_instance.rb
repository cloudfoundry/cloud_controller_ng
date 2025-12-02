module Fog
  module Google
    class SQL
      ##
      # Deletes a Cloud SQL instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/delete

      class Real
        def delete_instance(instance_id)
          @sql.delete_instance(@project, instance_id)
        end
      end

      class Mock
        def delete_instance(_instance_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
