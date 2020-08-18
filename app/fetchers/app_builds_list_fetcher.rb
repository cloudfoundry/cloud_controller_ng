require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppBuildsListFetcher < BaseListFetcher
    class << self
      def fetch_all(app_guid, message)
        dataset = BuildModel.dataset.where(app_guid: app_guid)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: BuildLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: BuildModel,
              )
        end

        if message.requested? :states
          dataset = dataset.where(state: message.states)
        end

        super(message, dataset, BuildModel)
      end

      attr_reader :app_guid, :message
    end
  end
end
