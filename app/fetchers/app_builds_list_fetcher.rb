module VCAP::CloudController
  class AppBuildsListFetcher
    def initialize(app_guid, message)
      @app_guid = app_guid
      @message = message
    end

    def fetch_all
      build_dataset = BuildModel.where(app_guid: app_guid)
      if message.requested? :states
        build_dataset.where(state: message.states)
      else
        build_dataset
      end
    end

    private

    attr_reader :app_guid, :message
  end
end
