require 'jobs/v3/services/service_broker_catalog_updater'

module VCAP::CloudController
  module V3
    class SynchronizeBrokerCatalogJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :warnings

      def initialize(broker_guid)
        @broker_guid = broker_guid
      end

      def perform
        @warnings = Perform.new(@broker_guid).perform
      end

      def job_name_in_configuration
        :synchronize_service_broker_catalog
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
        'service_broker.catalog.synchronize'
      end

      private

      attr_reader :broker_guid

      class Perform
        def initialize(broker_guid)
          @broker = ServiceBroker.find(guid: broker_guid)
          @catalog_updater = VCAP::CloudController::V3::ServiceBrokerCatalogUpdater.new(@broker)
        end

        def perform
          synchronizing_state

          warnings = @catalog_updater.refresh

          set_to_available_state

          warnings
        rescue
          failed_state
          raise
        end

        private

        attr_reader :broker, :warnings

        def set_to_available_state
          broker.update_state(ServiceBrokerStateEnum::AVAILABLE)
        end

        def synchronizing_state
          broker.update_state(ServiceBrokerStateEnum::SYNCHRONIZING)
        end

        def failed_state
          broker.update_state(ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
        end
      end
    end
  end
end
