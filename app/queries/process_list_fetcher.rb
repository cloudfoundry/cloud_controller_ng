module VCAP::CloudController
  class ProcessListFetcher
    def initialize(message)
      @message = message
    end

    def fetch_all
      dataset = ProcessModel.select_all(:apps)
      filter(dataset)
    end

    def fetch_for_spaces(space_guids:)
      dataset = join_spaces_if_necessary(ProcessModel.select_all(:apps), space_guids)
      filter(dataset)
    end

    def fetch_for_app
      app = AppModel.where(guid: @message.app_guid).eager(:space, :organization).all.first
      return nil unless app
      dataset = app.processes_dataset
      [app, filter(dataset)]
    end

    private

    def filter(dataset)
      dataset = dataset.where(type: @message.types) if @message.requested?(:types)

      if @message.requested?(:space_guids)
        dataset = join_spaces_if_necessary(dataset, @message.space_guids)
        dataset = dataset.where(spaces__guid: @message.space_guids)
      end

      if @message.requested?(:organization_guids)
        dataset = dataset.where(space_id: Organization.where(guid: @message.organization_guids).map(&:spaces).flatten.map(&:id))
      end

      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:guids)
        dataset = dataset.where(apps__guid: @message.guids)
      end

      dataset.eager(:space)
    end

    def join_spaces_if_necessary(dataset, space_guids)
      return dataset if dataset.opts[:join] && dataset.opts[:join].any? { |j| j.table == :spaces }
      dataset.join(:spaces, id: :space_id, guid: space_guids).select_all(:apps)
    end
  end
end
