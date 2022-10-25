require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class DropletListFetcher < BaseListFetcher
    class << self
      def fetch_all(message)
        dataset = DropletModel.dataset
        filter(message, nil, nil, dataset)
      end

      def fetch_for_spaces(message, space_guids)
        dataset = DropletModel.dataset
        filter(message, nil, space_guids, dataset)
      end

      def fetch_for_app(message)
        app = AppModel.where(guid: message.app_guid).first
        return nil unless app

        [app, filter(message, app, nil, app.droplets_dataset)]
      end

      def fetch_for_package(message)
        package = PackageModel.where(guid: message.package_guid).first
        return nil unless package

        [package, filter(message, nil, nil, package.droplets_dataset)]
      end

      private

      def filter(message, app, space_guids, dataset)
        if message.requested?(:current) && app
          dataset = dataset.extension(:null_dataset)
          return dataset.nullify unless app.droplet

          dataset = dataset.where(guid: app.droplet_guid)
        end

        if message.requested?(:app_guids)
          dataset = dataset.where(app_guid: message.app_guids)
        end

        if message.requested?(:states)
          dataset = dataset.where(state: message.states)
        end

        droplet_table_name = DropletModel.table_name

        if message.requested?(:organization_guids)
          space_guids_from_orgs = Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:guid)
          dataset = dataset.select_all(droplet_table_name).
                    join_table(:inner, AppModel.table_name, { guid: Sequel[:droplets][:app_guid], space_guid: space_guids_from_orgs }, { table_alias: :apps_orgs })
        end

        returned_scoped_space_guids = scoped_space_guids(permitted_space_guids: space_guids, filtered_space_guids: message.space_guids)
        unless returned_scoped_space_guids.nil?
          dataset = dataset.select_all(droplet_table_name).
                    join_table(:inner, AppModel.table_name, { guid: Sequel[:droplets][:app_guid], space_guid: returned_scoped_space_guids }, { table_alias: :apps_spaces })
        end

        if message.requested? :label_selector
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: DropletLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: DropletModel,
          )
        end

        dataset = dataset.exclude(state: DropletModel::STAGING_STATE).qualify(DropletModel.table_name)
        super(message, dataset, DropletModel)
      end

      def scoped_space_guids(permitted_space_guids:, filtered_space_guids:)
        return nil unless permitted_space_guids || filtered_space_guids
        return filtered_space_guids & permitted_space_guids if filtered_space_guids && permitted_space_guids
        return permitted_space_guids if permitted_space_guids
        return filtered_space_guids if filtered_space_guids
      end
    end
  end
end
