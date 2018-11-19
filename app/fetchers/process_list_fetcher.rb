module VCAP::CloudController
  class ProcessListFetcher
    def initialize(message)
      @message = message
    end

    def fetch_all
      filter(process_dataset)
    end

    def fetch_for_spaces(space_guids:)
      filter(process_dataset.where(Sequel.qualify(:space, :guid) => space_guids))
    end

    def fetch_for_app
      app = AppModel.where(guid: @message.app_guid).eager(:space, :organization).all.first
      return nil unless app

      [app, filter(app.processes_dataset)]
    end

    private

    def process_dataset
      ProcessModel.dataset.eager(:current_droplet).eager_graph_with_options({ space: :organization }, join_type: :inner)
    end

    def filter(dataset)
      dataset = dataset.where(type: @message.types) if @message.requested?(:types)

      if @message.requested?(:space_guids)
        dataset = dataset.where(Sequel.qualify(:space, :guid) => @message.space_guids)
      end

      if @message.requested?(:organization_guids)
        dataset = dataset.where(Sequel.qualify(:organization, :guid) => @message.organization_guids)
      end

      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:guids)
        dataset = dataset.where(Sequel.qualify(:processes, :guid) => @message.guids)
      end

      dataset
    end
  end
end
