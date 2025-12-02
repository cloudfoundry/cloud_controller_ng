require "fog/core/model"

module Fog
  module Google
    class SQL
      ##
      # An Operation resource contains information about database instance operations
      # such as create, delete, and restart
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/operations
      class Operation < Fog::Model
        identity :name

        attribute :kind, :aliases => "kind"
        attribute :self_link, :aliases => "selfLink"
        attribute :target_project, :aliases => "targetProject"
        attribute :target_id, :aliases => "targetId"
        attribute :target_link, :aliases => "targetLink"
        attribute :name, :aliases => "name"
        attribute :operation_type, :aliases => "operationType"
        attribute :status, :aliases => "status"
        attribute :user, :aliases => "user"
        attribute :insert_time, :aliases => "insertTime"
        attribute :start_time, :aliases => "startTime"
        attribute :end_time, :aliases => "endTime"
        attribute :error, :aliases => "error"
        attribute :import_context, :aliases => "importContext"
        attribute :export_context, :aliases => "exportContext"
        attribute :sql_export_options, :aliases => "sqlExportOptions"
        attribute :csv_export_options, :aliases => "csvExportOptions"

        DONE_STATE    = "DONE".freeze
        PENDING_STATE = "PENDING".freeze
        RUNNING_STATE = "RUNNING".freeze
        UNKNOWN_STATE = "UNKNOWN".freeze

        ##
        # Checks if the instance operation is pending
        #
        # @return [Boolean] True if the operation is pending; False otherwise
        def pending?
          status == PENDING_STATE
        end

        ##
        # Checks if the instance operation is done
        #
        # @return [Boolean] True if the operation is done; False otherwise
        def ready?
          status == DONE_STATE
        end

        ##
        # Reloads an instance operation
        #
        # @return [Fog::Google::SQL::Operation] Instance operation resource
        def reload
          requires :identity

          data = collection.get(identity)
          merge_attributes(data.attributes)
          self
        end
      end
    end
  end
end
