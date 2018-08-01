module VCAP::CloudController
  class ProcessListFetcher
    def initialize(message)
      @message = message
    end

    def fetch_all
      filter(ProcessModel.dataset)
    end

    def fetch_for_spaces(space_guids:)
      dataset = ProcessModel.dataset.where(space: Space.where(guid: space_guids))
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
        dataset = dataset.where(space: Space.where(guid: @message.space_guids))
      end

      if @message.requested?(:organization_guids)
        dataset = dataset.where(space: Space.where(organization: Organization.where(guid: @message.organization_guids)))
      end

      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:guids)
        dataset = dataset.where(guid: @message.guids)
      end

      dataset.eager(:space)
    end
  end
end
