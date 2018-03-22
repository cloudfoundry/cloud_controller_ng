module VCAP::CloudController
  class AppBuildsListFetcher
    def initialize(app_guid, message)
      @app_guid = app_guid
      @message = message
    end

    def fetch_all
      build_dataset = BuildModel.where(app_guid: [app_guid])
      filter(build_dataset)
    end

    def fetch_for_spaces(space_guids)
      app_guids = AppModel.where(guid: app_guid, space_guid: space_guids[:space_guids]).map(&:guid)
      build_dataset = BuildModel.where(app_guid: app_guids)
      filter(build_dataset)
    end

    private

    attr_reader :app_guid, :message

    def filter(dataset)
      if message.requested? :states
        dataset.where(state: message.states)
      else
        dataset
      end
    end
  end
end
