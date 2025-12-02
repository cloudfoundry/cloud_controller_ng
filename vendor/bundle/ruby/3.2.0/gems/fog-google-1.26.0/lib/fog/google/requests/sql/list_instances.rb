module Fog
  module Google
    class SQL
      ##
      # Lists instances under a given project in the alphabetical order of the instance name
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/list

      class Real
        def list_instances(filter: nil, max_results: nil, page_token: nil)
          @sql.list_instances(@project,
                              :filter => filter,
                              :max_results => max_results,
                              :page_token => page_token)
        end
      end

      class Mock
        def list_instances(_options: {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
