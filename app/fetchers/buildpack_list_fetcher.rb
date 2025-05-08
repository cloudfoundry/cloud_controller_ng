require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'cloud_controller/diego/lifecycles/lifecycles'
require 'fetchers/null_filter_query_generator'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class BuildpackListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, eager_loaded_associations: [])
        filter(message, buildpacks_dataset(eager_loaded_associations))
      end

      def buildpacks_dataset(eager_loaded_associations)
        Buildpack.dataset.eager(eager_loaded_associations)
      end

      def filter(message, dataset)
        dataset = dataset.where(name: message.names) if message.requested?(:names)

        dataset = NullFilterQueryGenerator.add_filter(dataset, :stack, message.stacks) if message.requested?(:stacks)

        dataset = dataset.where(lifecycle: message.lifecycle) if message.requested?(:lifecycle)

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: BuildpackLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Buildpack
          )
        end

        super(message, dataset, Buildpack)
      end
    end
  end
end
