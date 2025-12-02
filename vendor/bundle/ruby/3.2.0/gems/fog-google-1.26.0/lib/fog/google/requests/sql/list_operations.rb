module Fog
  module Google
    class SQL
      ##
      # Lists all instance operations that have been performed on the given Cloud SQL instance
      # in the reverse chronological order of the start time
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/operations/list

      class Real
        def list_operations(instance_id, max_results: nil, page_token: nil)
          @sql.list_operations(@project,
                               instance_id,
                               :max_results => max_results,
                               :page_token => page_token)
        end
      end

      class Mock
        def list_operations(_instance_id, _options: {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
