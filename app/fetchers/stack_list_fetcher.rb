require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class StackListFetcher < BaseListFetcher
    class << self
      def fetch_all(message)
        dataset = Stack.dataset
        filter(message, dataset)
      end

      def filter(message, dataset)
        if message.requested?(:names)
          dataset = dataset.where(name: message.names)
        end

        if message.requested?(:default)
          condition = { name: Stack.default.name }.yield_self do |c|
            ActiveModel::Type::Boolean.new.cast(message.default) ? c : Sequel.~(c)
          end
          dataset = dataset.where(condition)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: StackLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Stack,
          )
        end

        super(message, dataset, Stack)
      end
    end
  end
end
