module Fog
  module Google
    class SQL
      ##
      # Retrieves an instance operation that has been performed on an instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/operations/get

      class Real
        def get_operation(operation_id)
          @sql.get_operation(@project, operation_id)
        end
      end

      class Mock
        def get_operation(_operation_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
