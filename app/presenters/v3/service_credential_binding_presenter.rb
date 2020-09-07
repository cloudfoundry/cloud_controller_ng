require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingPresenter < BasePresenter
          def to_hash
            base_hash.merge(extra).merge(decorations)
          end

          private

          def base_hash
            {
              guid: @resource.guid,
              created_at: @resource.created_at,
              updated_at: @resource.updated_at,
              name: @resource.name,
              type: type
            }
          end

          def decorations
            @decorators.reduce({}) { |memo, d| d.decorate(memo, [@resource]) }
          end

          def type
            case @resource
            when VCAP::CloudController::ServiceKey
              'key'
            when VCAP::CloudController::ServiceBinding
              'app'
            end
          end

          def extra
            case type
            when 'app'
              {
                last_operation: last_operation,
                relationships: base_relationships.merge(app_relationship),
                links: base_links.merge(app_link)
              }
            when 'key'
              {
                last_operation: nil,
                relationships: base_relationships,
                links: base_links
              }
            end
          end

          def last_operation
            return nil if @resource.last_operation.blank?

            last_operation = @resource.last_operation

            {
              type: last_operation.type,
              state: last_operation.state,
              description: last_operation.description,
              created_at: last_operation.created_at,
              updated_at: last_operation.updated_at
            }
          end

          def base_links
            parameters = { parameters: "#{path_to_self}/parameters" } unless @resource.service_instance.user_provided_instance?

            {
              self: path_to_self,
              details: "#{path_to_self}/details",
              service_instance: "/v3/service_instances/#{@resource.service_instance_guid}"
            }.merge(parameters || {}).transform_values do |path|
              hrefify(path)
            end
          end

          def path_to_self
            "/v3/service_credential_bindings/#{@resource.guid}"
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

            { app: hrefify("/v3/apps/#{@resource.app_guid}") }
          end

          def hrefify(path)
            { href: url_builder.build_url(path: path) }
          end
        end
      end
    end
  end
end
