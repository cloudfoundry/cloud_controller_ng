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
          @formatter = VCAP::Services::ServiceBrokers::ValidationErrorsFormatter.new
          @service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithBrokerActor.new
          @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker, service_event_repository)
          @service_manager = VCAP::Services::ServiceBrokers::ServiceManager.new(service_event_repository)
        end

        def perform
          ServiceBroker.db.transaction do
            broker.update(update_params)

            catalog = VCAP::Services::ServiceBrokers::V2::Catalog.new(broker, broker_client.catalog)

            raise fail_with_invalid_catalog(catalog.validation_errors) unless catalog.valid?
            raise fail_with_incompatible_catalog(catalog.incompatibility_errors) unless catalog.compatible?
            unless client_manager.synchronize_clients_with_catalog(catalog)
              raise fail_with_invalid_catalog(client_manager.errors)
            end

            service_manager.sync_services_and_plans(catalog)
          end

          set_to_available_state
          collect_warnings
        rescue => e
          reset_to_previous_state

          if e.is_a?(Sequel::ValidationFailed)
            raise V3::ServiceBrokerUpdate::InvalidServiceBroker.new(e.errors.full_messages.join(','))
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

        attr_reader :broker_guid, :broker,
          :formatter, :client_manager, :service_event_repository,
          :service_manager, :warnings, :update_request, :previous_broker_state

        def broker_client
          @broker_client ||= VCAP::Services::ServiceClientProvider.provide(broker: broker)
        end

        def reset_to_previous_state
          if previous_broker_state.nil?
            broker.service_broker_state.destroy
          else
            broker.update_state(previous_broker_state)
          end
        end

        def set_to_available_state
          broker.update_state(ServiceBrokerStateEnum::AVAILABLE)
        end

        def fail_with_invalid_catalog(errors)
          full_message = formatter.format(errors)
          raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', full_message)
        end

        def fail_with_incompatible_catalog(errors)
          full_message = formatter.format(errors)
          raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogIncompatible', full_message)
        end

        def collect_warnings
          (service_manager.warnings + client_manager.warnings).map { |w| { detail: w } }
        end
      end
    end
  end
end
