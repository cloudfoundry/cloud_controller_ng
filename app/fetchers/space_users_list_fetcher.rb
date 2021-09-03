require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class SpaceUsersListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, space, readable_users_dataset)
        filter(message, space, readable_users_dataset)
      end

      private

      def filter(message, space, dataset)
        if message.requested?(:usernames)
          guids = uaa_client.ids_for_usernames_and_origins(message.usernames, message.origins)
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

        dataset = super(message, dataset, User)

        dataset.inner_join(SpaceDeveloper.table_name, user_id: :id).where(space_id: space.id).select_all(:users).
          union(dataset.inner_join(SpaceManager.table_name, user_id: :id).where(space_id: space.id).select_all(:users), alias: :users).
          union(dataset.inner_join(SpaceSupporter.table_name, user_id: :id).where(space_id: space.id).select_all(:users), alias: :users).
          union(dataset.inner_join(SpaceAuditor.table_name, user_id: :id).where(space_id: space.id).select_all(:users), alias: :users)
      end

      def uaa_client
        CloudController::DependencyLocator.instance.uaa_client
      end
    end
  end
end
