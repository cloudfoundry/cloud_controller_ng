require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ServicePlanPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          hash = {
            guid: service_plan.guid,
            created_at: service_plan.created_at,
            updated_at: service_plan.updated_at,
            visibility_type: service_plan.visibility_type,
            available: service_plan.active?,
            name: service_plan.name,
            free: service_plan.free,
            description: service_plan.description,
            maintenance_info: maintenance_info,
            broker_catalog: {
              id: service_plan.unique_id,
              metadata: metadata,
              maximum_polling_duration: service_plan.maximum_polling_duration,
              features: {
                bindable: service_plan.bindable?,
                plan_updateable: service_plan.plan_updateable?
              }
            },
            schemas: {
              service_instance: {
                create: parse_schema(service_plan.create_instance_schema),
                update: parse_schema(service_plan.update_instance_schema)
              },
              service_binding: {
                create: parse_schema(service_plan.create_binding_schema)
              }
            },
            relationships: relationships,
            metadata: {
              labels: hashified_labels(service_plan.labels),
              annotations: hashified_annotations(service_plan.annotations),
            },
            links: links
          }

          @decorators.reduce(hash) { |memo, d| d.decorate(memo, [service_plan]) }
        end

        private

        def metadata
          parse(service_plan.extra)
        end

        def maintenance_info
          service_plan.maintenance_info || {}
        end

        def parse_schema(schema)
          { parameters: JSON.parse(schema) }
        rescue JSON::ParserError
          {}
        end

        def parse(json)
          JSON.parse(json).deep_symbolize_keys
        rescue JSON::ParserError
          {}
        end

        def service_plan
          @resource
        end

        def relationships
          relationships = {
            service_offering: {
              data: {
                guid: service_plan.service.guid
              }
            }
          }

          if service_plan.service.service_broker.space_guid
            relationships[:space] = { data: { guid: service_plan.service.service_broker.space_guid } }
          end

          relationships
        end

        def links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          links = {
            self: {
              href: url_builder.build_url(path: "/v3/service_plans/#{service_plan.guid}")
            },
            service_offering: {
              href: url_builder.build_url(path: "/v3/service_offerings/#{service_plan.service.guid}")
            },
            visibility: {
              href: url_builder.build_url(path: "/v3/service_plans/#{service_plan.guid}/visibility")
            }
          }

          if service_plan.service.service_broker.space_guid
            links[:space] = { href: url_builder.build_url(path: "/v3/spaces/#{service_plan.service.service_broker.space_guid}") }
          end

          links
        end
      end
    end
  end
end
