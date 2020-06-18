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

        def to_hash
          {
            guid: broker.guid,
            created_at: broker.created_at,
            updated_at: broker.updated_at,
            name: broker.name,
            url: broker.broker_url,
            relationships: build_relationships,
            metadata: {
              labels: hashified_labels(broker.labels),
              annotations: hashified_annotations(broker.annotations),
            },
            links: build_links,
          }
        end

        private

        def broker
          @resource
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
          links = {
            self: {
              href: url_builder.build_url(path: "/v3/service_brokers/#{broker.guid}")
            },
            service_offerings: {
              href: url_builder.build_url(path: '/v3/service_offerings', query: "service_broker_guids=#{broker.guid}")
            },
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
