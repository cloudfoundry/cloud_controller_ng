require 'presenters/v3/base_presenter'
require 'models/helpers/metadata_helpers'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/api_url_builder'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceOfferingPresenter < BasePresenter
        def to_hash
          metadata = broker_metadata

          {
            guid: service_offering.guid,
            name: service_offering.label,
            description: service_offering.description,
            available: service_offering.active,
            tags: service_offering.tags,
            requires: service_offering.requires,
            created_at: service_offering.created_at,
            updated_at: service_offering.updated_at,
            shareable: shareable(metadata),
            broker_catalog: {
              id: service_offering.unique_id,
              metadata: metadata,
              features: {
                plan_updateable: service_offering.plan_updateable,
                bindable: service_offering.bindable,
                instances_retrievable: service_offering.instances_retrievable,
                bindings_retrievable: service_offering.bindings_retrievable,
              }
            },
            links: build_links,
            relationships: build_relationships,
          }
        end

        private

        def service_offering
          @resource
        end

        def shareable(metadata)
          metadata.nil? ? false : metadata['shareable'] == true
        end

        def broker_metadata
          JSON.parse(service_offering.extra)
        rescue JSON::ParserError
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: {
              href: url_builder.build_url(path: "/v3/service_offerings/#{service_offering.guid}")
            },
            service_plans: {
              href: url_builder.build_url(path: '/v3/service_plans', query: "service_offering_guids=#{service_offering.guid}")
            },
            service_broker: {
              href: url_builder.build_url(path: "/v3/service_brokers/#{service_offering.service_broker.guid}")
            }
          }
        end

        def build_relationships
          {
            service_broker: {
              data: {
                name: service_offering.service_broker.name,
                guid: service_offering.service_broker.guid
              }
            }
          }
        end
      end
    end
  end
end
