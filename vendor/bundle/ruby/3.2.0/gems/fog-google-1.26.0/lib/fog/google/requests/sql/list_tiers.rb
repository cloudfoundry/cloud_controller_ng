module Fog
  module Google
    class SQL
      ##
      # Lists all available service tiers for Google Cloud SQL
      #
      # @see https://developers.google.com/cloud-sql/docs/admin-api/v1beta3/tiers/list

      class Real
        def list_tiers
          @sql.list_tiers(@project)
        end
      end

      class Mock
        def list_tiers
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
