require "fog/core/model"

module Fog
  module Google
    class SQL
      ##
      # Represents a database user in a Cloud SQL instance.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/users
      class User < Fog::Model
        attribute :name
        attribute :etag
        attribute :host
        attribute :instance
        attribute :kind
        attribute :project

        def destroy(async = true)
          requires :instance, :name, :host

          # TODO(2.0): Add a deprecation warning here, depending on the decision in #27
          # This is a compatibility fix leftover from breaking named parameter change
          if async.is_a?(Hash)
            async = async[:async]
          end

          resp = service.delete_user(instance, host, name)
          operation = Fog::Google::SQL::Operations.new(:service => service).get(resp.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def save(password: nil)
          # TODO(2.0): make :host a required parameter
          # See: https://github.com/fog/fog-google/issues/462
          requires :instance, :name

          data = attributes
          data[:password] = password unless password.nil?
          if etag.nil?
            resp = service.insert_user(instance, data)
          else
            resp = service.update_user(instance, data)
          end

          operation = Fog::Google::SQL::Operations.new(:service => service).get(resp.name)
          operation.wait_for { ready? }
        end
      end
    end
  end
end
