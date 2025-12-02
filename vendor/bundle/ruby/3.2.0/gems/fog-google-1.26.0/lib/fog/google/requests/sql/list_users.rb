module Fog
  module Google
    class SQL
      ##
      # Lists users in the specified Cloud SQL instance.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/users/list

      class Real
        def list_users(instance_id)
          @sql.list_users(@project, instance_id)
        end
      end

      class Mock
        def list_operations(_instance_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
