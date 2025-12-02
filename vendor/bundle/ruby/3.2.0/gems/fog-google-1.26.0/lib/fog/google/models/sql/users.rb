require "fog/core/collection"
require "fog/google/models/sql/user"

module Fog
  module Google
    class SQL
      class Users < Fog::Collection
        model Fog::Google::SQL::User

        ##
        # Lists all Cloud SQL database users
        #
        # @return [Array<Fog::Google::SQL::User>] List of users
        def all(instance)
          data = service.list_users(instance).to_h[:items] || []
          load(data)
        end
      end
    end
  end
end
