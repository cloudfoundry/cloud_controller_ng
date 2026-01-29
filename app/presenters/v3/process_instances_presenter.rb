require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessInstancesPresenter < BasePresenter
        attr_reader :instances

        def initialize(process, instances)
          super(process)
          @instances = instances
        end

        def to_hash
          {
            resources: build_instances,
            links: build_links
          }
        end

        private

        def process
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
            self: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}/instances") },
            process: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}") }
          }
        end
      end
    end
  end
end
