require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceInstancePresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          h = {
            guid: service_instance.guid,
            created_at: service_instance.created_at,
            updated_at: service_instance.updated_at,
            name: service_instance.name,
            tags: service_instance.tags
          }

          h = if service_instance.class == ManagedServiceInstance
                h.merge({
                  type: 'managed',
                  maintenance_info: maintenance_info,
                  upgrade_available: upgrade_available,
                  dashboard_url: service_instance.dashboard_url,
                  last_operation: last_operation,
                })
              else
                h.merge({
                  type: 'user-provided',
                  syslog_drain_url: service_instance.syslog_drain_url,
                  route_service_url: service_instance.route_service_url
                })
              end

          h.merge({
            relationships: {
              space: {
                data: {
                  guid: service_instance.space.guid
                }
              }
            },
            metadata: {
              labels: hashified_labels(service_instance.labels),
              annotations: hashified_annotations(service_instance.annotations),
            },
            links: {
              self: {
                href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}")
              },
              space: {
                href: url_builder.build_url(path: "/v3/spaces/#{service_instance.space.guid}")
              }
            }
          })
        end

        private

        def url_builder
          VCAP::CloudController::Presenters::ApiUrlBuilder.new
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
      end
    end
  end
end
