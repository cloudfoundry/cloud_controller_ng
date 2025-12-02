require "fog/core/model"

module Fog
  module Google
    class SQL
      ##
      # A database instance backup run resource
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/backupRuns
      class BackupRun < Fog::Model
        identity :id

        attribute :description
        attribute :end_time, :aliases => "endTime"
        attribute :enqueued_time, :aliases => "enqueuedTime"
        attribute :error
        attribute :instance
        attribute :kind
        attribute :self_link, :aliases => "selfLink"
        attribute :start_time, :aliases => "startTime"
        attribute :status
        attribute :type
        attribute :window_start_time, :aliases => "windowStartTime"

        READY_STATUS = "DONE".freeze

        ##
        # Checks if the instance backup run is done
        #
        # @return [Boolean] True if the backup run is done; False otherwise
        def ready?
          status == READY_STATUS
        end
      end
    end
  end
end
