require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/null_filter_query_generator'

module VCAP::CloudController
  class BuildpackListFetcher
    def fetch_all(message, eager_loaded_associations: [])
      filter(message, buildpacks_dataset(eager_loaded_associations))
    end

    def buildpacks_dataset(eager_loaded_associations)
      Buildpack.dataset.eager(eager_loaded_associations)
    end

    def filter(message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      if message.requested?(:stacks)
        dataset = NullFilterQueryGenerator.add_filter(dataset, :stack, message.stacks)
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: BuildpackLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: Buildpack,
        )
      end

      dataset
    end
  end
end
