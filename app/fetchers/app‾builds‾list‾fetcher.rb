module VCAP::CloudController
  class AppBuildsListFetcher
    def initialize(app_guid, message)
      @app_guid = app_guid
      @message = message
    end

    def fetch_all
      dataset = BuildModel.dataset.where(app_guid: app_guid)

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: BuildLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: BuildModel,
        )
      end

      if message.requested? :states
        dataset = dataset.where(state: message.states)
      end

      dataset
    end

    private

    attr_reader :app_guid, :message
  end
end
