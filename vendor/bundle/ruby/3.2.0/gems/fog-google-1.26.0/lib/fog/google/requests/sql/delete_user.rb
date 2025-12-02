module Fog
  module Google
    class SQL
      ##
      # Deletes a user from a Cloud SQL instance.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/users/delete

      class Real
        def delete_user(instance_id, host, name)
          @sql.delete_user(@project, instance_id, host: host, name: name)
        end
      end

      class Mock
        def delete_user(_instance_id, _host, _name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
