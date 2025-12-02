module Fog
  module Google
    class SQL
      ##
      # Updates an existing user in a Cloud SQL instance.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/users/update

      class Real
        def update_user(instance_id, host, name, user)
          @sql.update_user(
            @project, instance_id, host, name,
            ::Google::Apis::SqladminV1beta4::User.new(user)
          )
        end
      end

      class Mock
        def update_user(_instance_id, _host, _name, _user)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
