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
      dataset = BuildModel.dataset

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

      dataset.where(app: filter_app_dataset(app_dataset))
    end

    def filter_app_dataset(app_dataset)
      if message.requested? :app_guids
        app_dataset = app_dataset.where(app_guid: message.app_guids)
      end
      app_dataset
    end
  end
end
