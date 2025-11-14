require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessInstancesPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def initialize(resource, show_secrets:, censored_message:, instances: {})
          @instances = instances
          super(resource, show_secrets:, censored_message:)
        end

        def to_hash
          {
            process_guid: process.guid,
            instances: build_instances,
            created_at: process.created_at,
            updated_at: process.updated_at,
            links: build_links
          }
        end

        private

        def process
          @resource
        end

        def build_instances
          @instances[process.guid].map do |index, instance|
            {
              index: index,
              state: instance[:state],
              uptime: instance[:uptime]
            }
          end
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}/instances") },
            process: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}") }
          }
        end
      end
    end
  end
end
