require "fog/core/collection"
require "fog/google/models/sql/operation"

module Fog
  module Google
    class SQL
      class Operations < Fog::Collection
        model Fog::Google::SQL::Operation

        ##
        # Lists all instance operations that have been performed on the given instance
        #
        # @param [String] instance_id Instance ID
        # @return [Array<Fog::Google::SQL::Operation>] List of instance operation resources
        def all(instance_id)
          data = []
          begin
            data = service.list_operations(instance_id).items || []
            data = data.map(&:to_h)
          rescue Fog::Errors::Error => e
            # Google SQL returns a 403 if we try to access a non-existing resource
            # The default behaviour in Fog is to return an empty Array
            raise e unless e.message == "The client is not authorized to make this request."
          end

          load(data)
        end

        ##
        # Retrieves an instance operation that has been performed on an instance
        #
        # @param [String] operation_id Instance operation ID
        # @return [Fog::Google::SQL::Operation] Instance operation resource
        def get(operation_id)
          if operation = service.get_operation(operation_id).to_h
            new(operation)
          end
        rescue ::Google::Apis::ClientError => e
          # Google SQL returns a 403 if we try to access a non-existing resource
          # The default behaviour in Fog is to return a nil
          raise e unless e.status_code == 404 || e.status_code == 403
          nil
        end
      end
    end
  end
end
