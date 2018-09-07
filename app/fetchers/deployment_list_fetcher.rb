module VCAP::CloudController
  class DeploymentListFetcher
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
      if message.requested? :app_guids
        app_dataset = app_dataset.where(app_guid: message.app_guids)
      end
      dataset = DeploymentModel.dataset.where(app: app_dataset)
      if message.requested? :states
        dataset = dataset.where(state: message.states)
      end
      dataset
    end
  end
end
