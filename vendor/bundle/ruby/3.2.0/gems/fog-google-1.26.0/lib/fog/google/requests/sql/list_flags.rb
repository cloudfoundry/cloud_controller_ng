module Fog
  module Google
    class SQL
      ##
      # List all available database flags for Google Cloud SQL instances
      #
      # @see https://developers.google.com/cloud-sql/docs/admin-api/v1beta3/flags/list

      class Real
        def list_flags(database_version: nil)
          @sql.list_flags(:database_version => database_version)
        end
      end

      class Mock
        def list_flags
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
