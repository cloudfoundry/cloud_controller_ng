module Fog
  module Google
    class SQL
      ##
      # Create a new user in a Cloud SQL instance.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/users/insert

      class Real
        def insert_user(instance_id, user)
          @sql.insert_user(@project, instance_id,
                           ::Google::Apis::SqladminV1beta4::User.new(**user))
        end
      end

      class Mock
        def insert_user(_instance_id, _user)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
