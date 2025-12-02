module Fog
  module Google
    class SQL
      ##
      # Retrieves a resource containing information about a Cloud SQL instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/get

      class Real
        def get_instance(instance_id)
          @sql.get_instance(@project, instance_id)
        end
      end

      class Mock
        def get_instance(_instance_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
