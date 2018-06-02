module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(message:)
      filter(message, joined_dataset)
    end

    def fetch_for_spaces(message:, space_guids:)
      dataset = joined_dataset.where(table_column_name(AppModel, :space_guid) => space_guids)
      filter(message, dataset)
    end

    def fetch_for_app(message:)
      app_dataset = AppModel.where(guid: message.app_guid).eager(:space, :organization)
      app = app_dataset.first
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

      if message.requested? :guids
        dataset = dataset.where(table_column_name(PackageModel, :guid) => message.guids)
      end

      if message.requested? :app_guids
        dataset = dataset.where(table_column_name(AppModel, :guid) => message.app_guids)
      end

      if message.requested? :space_guids
        dataset = dataset.where(table_column_name(AppModel, :space_guid) => message.space_guids)
      end

      if message.requested? :organization_guids
        dataset = dataset.where(table_column_name(AppModel, :space_guid) => Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:guid))
      end

      dataset
    end
  end
end
