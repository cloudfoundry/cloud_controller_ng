require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingPresenter < BasePresenter
          def to_hash
            {
              guid: @resource.guid,
              type: @resource.type,
              name: @resource.name,
              created_at: @resource.created_at,
              updated_at: @resource.updated_at,
              last_operation: last_operation,
              relationships: build_relationships,
              links: build_links
            }
          end

          private

          def build_relationships
            base_relationships.merge(app_relationship)
          end

          def build_links
            base_links.merge(app_link)
          end

          def last_operation
            return nil if @resource.last_operation_id.blank?

            {
              type: @resource.last_operation_type,
              state: @resource.last_operation_state,
              description: @resource.last_operation_description,
              created_at: @resource.last_operation_created_at,
              updated_at: @resource.last_operation_updated_at
            }
          end

          def base_links
            {
              self: { href: url_builder.build_url(path: "/v3/service_credential_bindings/#{@resource.guid}") },
              service_instance: {
                href: url_builder.build_url(path: "/v3/service_instances/#{@resource.service_instance_guid}")
              }
            }
          end

          def base_relationships
            {
              service_instance: { data: { guid: @resource.service_instance_guid } }
            }
          end

          def app_relationship
            return {} if @resource.app_guid.blank?

            { app: { data: { guid: @resource.app_guid } } }
          end

          def app_link
            return {} if @resource.app_guid.blank?

            { app: { href: url_builder.build_url(path: "/v3/apps/#{@resource.app_guid}") } }
          end
        end
      end
    end
  end
end
