require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class SpaceListFetcher < BaseListFetcher
    class << self
      def fetch(message:, guids:, eager_loaded_associations: [])
        dataset = Space.where(guid: guids).eager(eager_loaded_associations)
        filter(message, dataset)
      end

      def fetch_all(message:, eager_loaded_associations: [])
        dataset = Space.dataset.eager(eager_loaded_associations)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested? :names
          dataset = dataset.where(name: message.names)
        end

        if message.requested? :organization_guids
          dataset = dataset.
                    join(:organizations, id: :organization_id).
                    where(Sequel[:organizations][:guid] => message.organization_guids).
                    qualify(:spaces)
        end

        if message.requested? :label_selector
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: SpaceLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Space,
          )
        end

        super(message, dataset, Space)
      end
    end
  end
end
