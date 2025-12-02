module Fog
  module Google
    class DNS
      ##
      # Represents a Change resource
      #
      # @see https://developers.google.com/cloud-dns/api/v1/changes
      class Change < Fog::Model
        identity :id

        attribute :kind
        attribute :start_time, :aliases => "startTime"
        attribute :status
        attribute :additions
        attribute :deletions

        DONE_STATE    = "done".freeze
        PENDING_STATE = "pending".freeze

        ##
        # Checks if the change operation is pending
        #
        # @return [Boolean] True if the change operation is pending; False otherwise
        def pending?
          status == PENDING_STATE
        end

        ##
        # Checks if the change operation is done
        #
        # @return [Boolean] True if the change operation is done; False otherwise
        def ready?
          status == DONE_STATE
        end
      end
    end
  end
end
