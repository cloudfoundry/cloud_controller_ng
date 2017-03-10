module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(message:)
      app_dataset = AppModel.select(:id)
      filter(message, app_dataset)
    end

    def fetch_for_spaces(message:, space_guids:)
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)

      filter(message, app_dataset)
    end

    def fetch_for_app(message:)
      app_dataset = AppModel.where(guid: message.app_guid).eager(:space, :organization)
      app = app_dataset.first
      return nil unless app

      [app, filter(message, app_dataset)]
    end

    private

    def filter(message, dataset)
      package_dataset = PackageModel.dataset
      filter_package_dataset(message, package_dataset).where(app: filter_app_dataset(message, dataset))
    end

    def filter_package_dataset(message, package_dataset)
      if message.requested? :states
        package_dataset = package_dataset.where(state: message.states)
      end

      if message.requested? :types
        package_dataset = package_dataset.where(type: message.types)
      end

      if message.requested? :guids
        package_dataset = package_dataset.where(:"#{PackageModel.table_name}__guid" => message.guids)
      end

      package_dataset
    end

    def filter_app_dataset(message, app_dataset)
      if message.requested? :app_guids
        app_dataset = app_dataset.where(app_guid: message.app_guids)
      end

      if message.requested? :space_guids
        app_dataset = app_dataset.where(space_guid: message.space_guids)
      end

      if message.requested? :organization_guids
        app_dataset = app_dataset.where(space_guid: Organization.where(guid: message.organization_guids).all.map(&:spaces).flatten.map(&:guid))
      end

      app_dataset
    end
  end
end
