require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class UserListFetcher
    class << self
      def fetch_all(message, readable_users_dataset)
        filter(message, readable_users_dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: UserLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: User,
          )
        end

        dataset
      end
    end
  end
end
