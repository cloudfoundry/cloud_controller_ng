module VCAP::CloudController
  module V3
    class UpdateBrokerJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :warnings

      def initialize(update_request_guid, broker_guid, previous_broker_state)
        @update_request_guid = update_request_guid
        @broker_guid = broker_guid
        @previous_broker_state = previous_broker_state
      end

      def perform
        @warnings = Perform.new(@update_request_guid, @previous_broker_state).perform
      end

      def job_name_in_configuration
        :update_service_broker
      end

      def max_attempts
        1
      end

      def resource_type
        'service_brokers'
      end

      def resource_guid
        broker_guid
      end

      def display_name
        'service_broker.update'
      end

      private

      attr_reader :update_request_guid, :broker_guid

      class Perform
        def initialize(update_request_guid, previous_broker_state)
          @update_request_guid = update_request_guid
          @update_request = ServiceBrokerUpdateRequest.find(guid: update_request_guid)
          @broker = ServiceBroker.find(id: @update_request.service_broker_id)
          @previous_broker_state = previous_broker_state
          @catalog_updater = VCAP::CloudController::V3::ServiceBrokerCatalogUpdater.new(@broker)
        end

        def perform
          ServiceBroker.db.transaction do
            broker.update(update_params)

            @warnings = @catalog_updater.refresh

            broker.update(state: ServiceBrokerStateEnum::AVAILABLE)
          end

          @warnings
        rescue => e
          broker.update(state: previous_broker_state)

          if e.is_a?(Sequel::ValidationFailed)
            raise V3::ServiceBrokerUpdate::InvalidServiceBroker.new(e.message)
          end

          raise e
        ensure
          update_request.destroy
        end

        private

        def update_params
          params = {}
          params[:name] = update_request.name unless update_request.name.nil?
          params[:broker_url] = update_request.broker_url unless update_request.broker_url.nil?
          unless update_request.authentication.nil?
            auth = JSON.parse(update_request.authentication)
            params[:auth_username] = auth.dig('credentials', 'username')
            params[:auth_password] = auth.dig('credentials', 'password')
          end
          params
        end

        attr_reader :broker, :update_request, :previous_broker_state
      end
    end
  end
end
