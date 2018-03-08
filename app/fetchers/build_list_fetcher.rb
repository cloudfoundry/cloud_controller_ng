module VCAP::CloudController
  class BuildListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_all
      filter(AppModel.dataset)
    end

    def fetch_for_spaces(space_guids:)
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)
      filter(app_dataset)
    end

    private

    attr_reader :message

    def filter(app_dataset)
      build_dataset = BuildModel.dataset
      filter_build_dataset(build_dataset).where(app: filter_app_dataset(app_dataset))
    end

    def filter_build_dataset(build_dataset)
      if message.requested? :states
        build_dataset = build_dataset.where(state: message.states)
      end
      build_dataset
    end

    def filter_app_dataset(app_dataset)
      if message.requested? :app_guids
        app_dataset = app_dataset.where(app_guid: message.app_guids)
      end
      app_dataset
    end
  end
end
