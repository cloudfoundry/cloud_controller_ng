require 'presenters/mixins/metadata_presentation_helpers'
require 'jobs/cc_job'

module VCAP::CloudController
  module V3
    class UpdateBrokerJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :warnings

      def initialize(update_request_guid, broker_guid, previous_broker_state, user_audit_info:)
        @update_request_guid = update_request_guid
        @broker_guid = broker_guid
        @previous_broker_state = previous_broker_state
        @user_audit_info = user_audit_info
      end

      def perform
        @warnings = Perform.new(update_request_guid, previous_broker_state, user_audit_info: user_audit_info).perform
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

      attr_reader :update_request_guid, :broker_guid, :previous_broker_state, :user_audit_info

      class Perform
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def initialize(update_request_guid, previous_broker_state, user_audit_info:)
          @update_request_guid = update_request_guid
          @update_request = ServiceBrokerUpdateRequest.find(guid: update_request_guid)
          @broker = ServiceBroker.find(id: @update_request.service_broker_id)
          @previous_broker_state = previous_broker_state
          @catalog_updater = VCAP::CloudController::V3::ServiceBrokerCatalogUpdater.new(@broker, user_audit_info: user_audit_info)
        end

        def perform
          ServiceBroker.db.transaction do
            broker.update(update_params)

            @warnings = @catalog_updater.refresh unless only_name_change?(update_params)

            MetadataUpdate.update(broker, ServiceBrokerUpdateMetadataMessage.new(build_metadata_request_params))
            broker.update(state: ServiceBrokerStateEnum::AVAILABLE)
          end

          @warnings
        rescue => e
          begin
            broker.update(state: previous_broker_state)
          rescue
            raise CloudController::Errors::V3::ApiError.new_from_details('ServiceBrokerGone') if broker.nil?
          end

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

        def only_name_change?(params)
          params.keys == [:name]
        end

        def build_metadata_request_params
          {
            metadata: {
              labels: hashified_labels(update_request.labels),
              annotations: hashified_annotations(update_request.annotations)
            }
          }
        end

        attr_reader :broker, :update_request, :previous_broker_state
      end
    end
  end
end
