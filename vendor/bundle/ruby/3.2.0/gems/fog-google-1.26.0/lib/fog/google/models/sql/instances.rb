require "fog/core/collection"
require "fog/google/models/sql/instance"

module Fog
  module Google
    class SQL
      class Instances < Fog::Collection
        model Fog::Google::SQL::Instance

        ##
        # Lists all instance
        #
        # @return [Array<Fog::Google::SQL::Instance>] List of instance resources
        def all
          data = service.list_instances.to_h[:items] || []
          load(data)
        end

        ##
        # Retrieves an instance
        #
        # @param [String] instance_id Instance ID
        # @return [Fog::Google::SQL::Instance] Instance resource
        def get(instance_id)
          instance = service.get_instance(instance_id).to_h
          # XXX if we pass `nil` to get() it returns empty DB object with
          # kind set to "sql#instancesList"
          # see https://github.com/google/google-api-ruby-client/issues/699
          if instance[:kind].eql?("sql#instance")
            new(instance)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404 || e.status_code == 403
          nil
        end
      end
    end
  end
end
