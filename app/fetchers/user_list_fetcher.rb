require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class UserListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, readable_users_dataset)
        filter(message, readable_users_dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:usernames)
          guids = uaa_client.ids_for_usernames_and_origins(message.usernames, message.origins)
          dataset = dataset.where(guid: guids)
        end

        if message.requested?(:partial_usernames)
          guids = uaa_client.ids_for_usernames_and_origins(message.partial_usernames, message.origins, false)
          dataset = dataset.where(guid: guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: UserLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: User,
          )
        end

        super(message, dataset, User)
      end

      def uaa_client
        CloudController::DependencyLocator.instance.uaa_client
      end
    end
  end
end
