require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class PackageListFetcher < BaseListFetcher
    class << self
      def fetch_all(message:)
        filter(message, joined_dataset)
      end

      def fetch_for_spaces(message:, space_guids:)
        dataset = joined_dataset.where(table_column_name(AppModel, :space_guid) => space_guids)
        filter(message, dataset)
      end

      def fetch_for_app(message:)
        app = AppModel.where(guid: message.app_guid).first
        return [nil, nil] unless app

        dataset = PackageModel.dataset.select_all(PackageModel.table_name).
                  join(AppModel.table_name, guid: :app_guid).
                  where(table_column_name(AppModel, :guid) => message.app_guid)

        [app, filter(message, dataset)]
      end

      private

      def table_column_name(table_class, name)
        "#{table_class.table_name}__#{name}".to_sym
      end

      def joined_dataset
        PackageModel.dataset.select_all(PackageModel.table_name).
          join(AppModel.table_name, guid: :app_guid)
      end

      def filter(message, dataset)
        if message.requested? :states
          dataset = dataset.where(table_column_name(PackageModel, :state) => message.states)
        end

        if message.requested? :types
          dataset = dataset.where(table_column_name(PackageModel, :type) => message.types)
        end

        if message.requested? :app_guids
          dataset = dataset.where(table_column_name(AppModel, :guid) => message.app_guids)
        end

        if message.requested? :space_guids
          dataset = dataset.where(table_column_name(AppModel, :space_guid) => message.space_guids)
        end

        if message.requested? :organization_guids
          dataset = dataset.
                    join(:spaces, guid: :space_guid).
                    join(:organizations, id: :organization_id).
                    where(Sequel[:organizations][:guid] => message.organization_guids).
                    qualify(:packages)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: PackageLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: PackageModel,
          )
        end

        super(message, dataset, PackageModel)
      end
    end
  end
end
