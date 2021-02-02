require_relative 'base_presenter'
require 'presenters/mixins/last_operation_helper'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingPresenter < BasePresenter
          include VCAP::CloudController::Presenters::Mixins::LastOperationHelper
          include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

          class << self
            def associated_resources
              [
                :service_instance_sti_eager_load,
                :labels_sti_eager_load,
                :annotations_sti_eager_load,
                :operation_sti_eager_load
              ]
            end
          end

          def to_hash
            base_hash.merge(extra).merge(decorations)
          end

          private

          def binding
            @resource
          end

          def base_hash
            {
              guid: binding.guid,
              created_at: binding.created_at,
              updated_at: binding.updated_at,
              name: binding.name,
              type: type,
              last_operation: last_operation(binding),
              metadata: {
                labels: hashified_labels(binding.labels),
                annotations: hashified_annotations(binding.annotations),
              }
            }
          end

          def decorations
            @decorators.reduce({}) { |memo, d| d.decorate(memo, [binding]) }
          end

          def type
            case binding
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
                relationships: base_relationships.merge(app_relationship),
                links: base_links.merge(app_link)
              }
            when 'key'
              {
                relationships: base_relationships,
                links: base_links
              }
            end
          end

          def base_links
            parameters = { parameters: "#{path_to_self}/parameters" } unless binding.service_instance.user_provided_instance?

            {
              self: path_to_self,
              details: "#{path_to_self}/details",
              service_instance: "/v3/service_instances/#{binding.service_instance_guid}"
            }.merge(parameters || {}).transform_values do |path|
              hrefify(path)
            end
          end

          def path_to_self
            "/v3/service_credential_bindings/#{binding.guid}"
          end

          def base_relationships
            {
              service_instance: { data: { guid: binding.service_instance_guid } }
            }
          end

          def app_relationship
            return {} if binding.app_guid.blank?

            { app: { data: { guid: binding.app_guid } } }
          end

          def app_link
            return {} if binding.app_guid.blank?

            { app: hrefify("/v3/apps/#{binding.app_guid}") }
          end

          def hrefify(path)
            { href: url_builder.build_url(path: path) }
          end
        end
      end
    end
  end
end
