require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessInstancesPresenter < BasePresenter
        attr_reader :process

        def initialize(instances, process)
          super(instances)
          @process = process
        end

        def to_hash
          {
            resources: build_instances,
            links: build_links
          }
        end

        private

        def instances
          @resource
        end

        def build_instances
          instances.map do |index, instance|
            {
              index: index,
              state: instance[:state],
              since: instance[:since]
            }
          end
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}/process_instances") },
            process: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}") }
          }
        end
      end
    end
  end
end
