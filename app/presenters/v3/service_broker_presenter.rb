require 'presenters/v3/base_presenter'
require 'models/helpers/metadata_helpers'
require 'presenters/mixins/metadata_presentation_helpers'
require 'models/services/service_broker_state_enum'
require 'presenters/api_url_builder'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceBrokerPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        STATES = {
            VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING => 'synchronization in progress',
            VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED => 'synchronization failed',
            VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE => 'available',
            VCAP::CloudController::ServiceBrokerStateEnum::DELETE_IN_PROGRESS => 'delete in progress',
            VCAP::CloudController::ServiceBrokerStateEnum::DELETE_FAILED => 'delete failed'
        }.tap { |s| s.default = 'available' }.freeze

        def to_hash
          {
            guid: broker.guid,
            name: broker.name,
            url: broker.broker_url,
            available: status == 'available',
            status: status,
            created_at: broker.created_at,
            updated_at: broker.updated_at,
            relationships: build_relationships,
            links: build_links,
            metadata: {
                labels: hashified_labels(broker.labels),
                annotations: hashified_annotations(broker.annotations)
            }
          }
        end

        private

        def broker
          @resource
        end

        def status
          STATES[broker.state]
        end

        def build_relationships
          if broker.space_guid.nil?
            {}
          else
            {
              space: {
                data: {
                  guid: broker.space_guid
                }
              }
            }
          end
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          links = {
            self: {
              href: url_builder.build_url(path: "/v3/service_brokers/#{broker.guid}")
            }
          }

          if broker.space_guid
            links[:space] = { href: url_builder.build_url(path: "/v3/spaces/#{broker.space_guid}") }
          end

          links
        end
      end
    end
  end
end
