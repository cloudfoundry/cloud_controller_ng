require 'presenters/v3/base_presenter'
require 'models/helpers/metadata_helpers'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/api_url_builder'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceOfferingPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        class << self
          # :labels and :annotations come from MetadataPresentationHelpers
          def associated_resources
            super + [:service_broker]
          end
        end

        def to_hash
          metadata = broker_metadata

          hash = {
            guid: service_offering.guid,
            created_at: service_offering.created_at,
            updated_at: service_offering.updated_at,
            name: service_offering.label,
            description: service_offering.description,
            available: service_offering.active,
            tags: service_offering.tags,
            requires: service_offering.requires,
            shareable: shareable(metadata),
            documentation_url: documentation_url(metadata),
            broker_catalog: {
              id: service_offering.unique_id,
              metadata: metadata,
              features: {
                plan_updateable: service_offering.plan_updateable,
                bindable: service_offering.bindable,
                instances_retrievable: service_offering.instances_retrievable,
                bindings_retrievable: service_offering.bindings_retrievable,
                allow_context_updates: service_offering.allow_context_updates,
              }
            },
            relationships: build_relationships,
            metadata: {
              labels: hashified_labels(service_offering.labels),
              annotations: hashified_annotations(service_offering.annotations),
            },
            links: build_links,
          }

          @decorators.reduce(hash) { |memo, d| d.decorate(memo, [service_offering]) }

          hash
        end

        private

        def service_offering
          @resource
        end

        def shareable(metadata)
          metadata['shareable'] == true
        end

        def documentation_url(metadata)
          metadata['documentationUrl'] || ''
        end

        def broker_metadata
          return {} unless service_offering.extra

          JSON.parse(service_offering.extra)
        rescue JSON::ParserError
          {}
        end

        def build_links
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
                guid: service_offering.service_broker.guid
              }
            }
          }
        end
      end
    end
  end
end
