require 'json'
require 'json-schema'
require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ServicePlanPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        class << self
          # :labels and :annotations come from MetadataPresentationHelpers
          def associated_resources
            super + [:service_plan_visibilities, { service: :service_broker }, { service: { service_broker: :space } }]
          end
        end

        def to_hash
          hash = {
            guid: service_plan.guid,
            created_at: service_plan.created_at,
            updated_at: service_plan.updated_at,
            name: service_plan.name,
            visibility_type: service_plan.visibility_type,
            available: service_plan.active?,
            free: service_plan.free,
            costs: costs,
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
                create:
                  {
                    parameters: parse_schema(service_plan.create_instance_schema)
                  },
                update: {
                  parameters: parse_schema(service_plan.update_instance_schema)
                }
              },
              service_binding: {
                create: {
                  parameters: parse_schema(service_plan.create_binding_schema)
                }
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

        def costs
          cost_result = []
          if metadata[:costs]
            validation_errors = JSON::Validator.fully_validate(costs_schema, metadata[:costs])
            return cost_result unless validation_errors.none?

            metadata[:costs].each do |cost|
              unit = cost[:unit].to_s
              cost[:amount].each do |currency, amount|
                return [] if currency.empty?

                cost_result << {
                  currency: currency.to_s.upcase,
                  amount: amount.to_f,
                  unit: unit
                }
              end
            end
          end
          cost_result
        end

        def maintenance_info
          service_plan.maintenance_info || {}
        end

        def parse_schema(schema)
          return {} unless schema

          JSON.parse(schema)
        rescue JSON::ParserError
          {}
        end

        def parse(json)
          return {} unless json

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

        def costs_schema
          {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'required' => %w(amount unit),
              'properties' => {
                'amount' => {
                  'type' => 'object',
                  'minProperties' => 1,
                  'additionalProperties' => {
                    'type' => 'number'
                  }
                },
                'unit' => {
                  'type' => 'string',
                  'minLength' => 1
                }
              }
            }
          }
        end
      end
    end
  end
end
