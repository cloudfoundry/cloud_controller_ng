module VCAP::CloudController
  class ProcessListFetcher
    def fetch_all(message:)
      pagination_options = message.pagination_options
      dataset = ProcessModel.select_all(:apps)
      dataset = filter(dataset, message)
      paginate(dataset, pagination_options)
    end

    def fetch_for_spaces(space_guids:, message:)
      pagination_options = message.pagination_options
      dataset = join_spaces_if_necessary(ProcessModel.select_all(:apps), space_guids)
      dataset = filter(dataset, message)
      paginate(dataset, pagination_options)
    end

    def fetch_for_app(app_guid:, message:)
      pagination_options = message.pagination_options
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app
      dataset = app.processes_dataset
      dataset = filter(dataset, message)
      [app, paginate(dataset, pagination_options)]
    end

    private

    def paginate(dataset, pagination_options)
      dataset = dataset.eager(:space)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end

    def filter(dataset, message)
      dataset = dataset.where(type: message.types) if message.requested?(:types)

      if message.requested?(:space_guids)
        dataset = join_spaces_if_necessary(dataset, message.space_guids)
        dataset = dataset.where(spaces__guid: message.space_guids)
      end

      if message.requested?(:organization_guids)
        dataset = dataset.where(space_id: Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:id))
      end

      if message.requested?(:app_guids)
        dataset = dataset.where(app_guid: message.app_guids)
      end

      dataset
    end

    def join_spaces_if_necessary(dataset, space_guids)
      return dataset if dataset.opts[:join] && dataset.opts[:join].any? { |j| j.table == :spaces }
      dataset.join(:spaces, id: :space_id, guid: space_guids).select_all(:apps)
    end
  end
end
