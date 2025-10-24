require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceInstancePresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        class << self
          # :labels and :annotations come from MetadataPresentationHelpers
          def associated_resources
            super + %i[
              space
              service_instance_operation
              service_plan_sti_eager_load
            ]
          end
        end

        def to_hash
          hash = correct_order(
            hash_common.deep_merge(
              if service_instance.instance_of?(ManagedServiceInstance)
                hash_additions_managed
              else
                hash_additions_user_provided
              end
            )
          )

          @decorators.reduce(hash) { |memo, d| d.decorate(memo, [service_instance]) }
        end

        private

        def hash_common
          {
            guid: service_instance.guid,
            created_at: service_instance.created_at,
            updated_at: service_instance.updated_at,
            name: service_instance.name,
            tags: service_instance.tags,
            last_operation: last_operation,
            relationships: {
              space: {
                data: {
                  guid: service_instance.space.guid
                }
              }
            },
            metadata: {
              labels: merged_labels,
              annotations: hashified_annotations(service_instance.annotations)
            },
            links: {
              self: {
                href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}")
              },
              space: {
                href: url_builder.build_url(path: "/v3/spaces/#{service_instance.space.guid}")
              },
              service_credential_bindings: {
                href: url_builder.build_url(
                  path: '/v3/service_credential_bindings',
                  query: "service_instance_guids=#{service_instance.guid}"
                )
              },
              service_route_bindings: {
                href: url_builder.build_url(
                  path: '/v3/service_route_bindings',
                  query: "service_instance_guids=#{service_instance.guid}"
                )
              }
            }
          }
        end

        def hash_additions_managed
          hash = {
            type: 'managed',
            maintenance_info: maintenance_info,
            upgrade_available: upgrade_available,
            dashboard_url: service_instance.dashboard_url,
            relationships: {
              service_plan: {
                data: {
                  guid: service_instance.service_plan.guid
                }
              }
            },
            links: {
              service_plan: {
                href: url_builder.build_url(path: "/v3/service_plans/#{service_instance.service_plan.guid}")
              },
              parameters: {
                href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}/parameters")
              },
              shared_spaces: {
                href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces")
              }
            }
          }
          
          # Add broker metadata if present
          if service_instance.broker_metadata.present?
            hash[:broker_metadata] = service_instance.broker_metadata
          end
          
          hash
        end

        def hash_additions_user_provided
          {
            type: 'user-provided',
            syslog_drain_url: service_instance.syslog_drain_url,
            route_service_url: service_instance.route_service_url,
            links: {
              credentials: {
                href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}/credentials")
              }
            }
          }
        end

        def correct_order(hash)
          relationships = hash.delete(:relationships)
          metadata = hash.delete(:metadata)
          links = hash.delete(:links)
          hash.merge({
                       relationships:,
                       metadata:,
                       links:
                     })
        end

        def service_instance
          @resource
        end

        def maintenance_info
          service_instance.maintenance_info || {}
        end

        def upgrade_available
          plan_maintenance_info = service_instance.service_plan.maintenance_info || {}
          maintenance_info['version'] != plan_maintenance_info['version']
        end

        def last_operation
          return {} if service_instance.last_operation.nil?

          service_instance.last_operation.to_hash({})
        end

        def merged_labels
          # Start with existing CF labels
          cf_labels = hashified_labels(service_instance.labels)
          
          # Get broker metadata labels if they exist (only for managed service instances)
          broker_labels = {}
          if service_instance.is_a?(ManagedServiceInstance) && service_instance.broker_metadata.present?
            broker_metadata_labels = service_instance.broker_metadata.dig('labels')
            broker_labels = broker_metadata_labels if broker_metadata_labels.is_a?(Hash)
          end
          
          # Merge broker labels into CF labels (broker labels take precedence for conflicts)
          cf_labels.merge(broker_labels)
        end
      end
    end
  end
end
